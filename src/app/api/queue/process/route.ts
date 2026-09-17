import {NextResponse} from 'next/server';import {getAdminClient} from '@/lib/supabase-admin';import {getWhatsAppProvider} from '@/lib/provider';
export const runtime='nodejs';

function positiveInt(value:string|undefined,fallback:number,max:number){const n=Number(value);return Number.isInteger(n)&&n>0?Math.min(n,max):fallback}

export async function POST(req:Request){
  const secret=process.env.QUEUE_WORKER_SECRET;
  if(!secret||req.headers.get('authorization')!==`Bearer ${secret}`)return NextResponse.json({error:'Unauthorized'},{status:401});
  const db=getAdminClient();
  const limit=positiveInt(process.env.QUEUE_BATCH_SIZE,50,200);
  const maxRetries=positiveInt(process.env.QUEUE_MAX_RETRIES,5,20);
  const now=new Date().toISOString();
  const {data:rows,error}=await db.from('wa_campaign_recipients')
    .select('id,campaign_id,customer_id,phone,idempotency_key,retry_count,wa_campaigns!inner(template_id,status,wa_templates!inner(template_name,language_code))')
    .eq('status','queued')
    .in('wa_campaigns.status',['processing'])
    .or(`next_retry_at.is.null,next_retry_at.lte.${now}`)
    .order('queued_at')
    .limit(limit);
  if(error)return NextResponse.json({error:error.message},{status:500});
  const provider=getWhatsAppProvider();let sent=0,failed=0,claimed=0;
  for(const r of rows||[]){
    const claim=await db.from('wa_campaign_recipients').update({status:'processing',processing_at:new Date().toISOString()}).eq('id',r.id).eq('status','queued').select('id');
    if(!claim.data?.length)continue;claimed++;
    try{
      const campaign:any=r.wa_campaigns;const c=Array.isArray(campaign)?campaign[0]:campaign;
      if(!c||c.status!=='processing')throw new Error('Campaign is not processing');
      const template=Array.isArray(c.wa_templates)?c.wa_templates[0]:c.wa_templates;
      if(!template)throw new Error('Campaign template missing');
      const result=await provider.sendTemplate({to:r.phone,templateName:template.template_name,languageCode:template.language_code,idempotencyKey:r.idempotency_key});
      const sentAt=new Date().toISOString();
      const {error:messageError}=await db.from('wa_messages').insert({campaign_id:r.campaign_id,recipient_id:r.id,customer_id:r.customer_id,phone:r.phone,provider:result.provider,provider_message_id:result.messageId,status:'sent',sent_at:sentAt,provider_response:result.raw});
      if(messageError)throw messageError;
      await db.from('wa_campaign_recipients').update({status:'sent',sent_at:sentAt,next_retry_at:null,failure_reason:null}).eq('id',r.id);sent++;
    }catch(e){
      const retries=Number(r.retry_count||0)+1,terminal=retries>=maxRetries;
      await db.from('wa_campaign_recipients').update({status:terminal?'failed':'queued',retry_count:retries,next_retry_at:terminal?null:new Date(Date.now()+Math.min(60,2**retries)*60000).toISOString(),processing_at:null,failed_at:terminal?new Date().toISOString():null,failure_reason:e instanceof Error?e.message.slice(0,1000):String(e).slice(0,1000)}).eq('id',r.id);failed++;
    }
  }
  return NextResponse.json({selected:(rows||[]).length,claimed,sent,failed});
}
