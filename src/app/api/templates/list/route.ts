import {NextResponse} from 'next/server';import {getAdminClient} from '@/lib/supabase-admin';
export async function GET(){const {data,error}=await getAdminClient().from('wa_templates').select('id,template_name,status').eq('status','approved').order('template_name');if(error)return NextResponse.json({error:error.message},{status:500});return NextResponse.json({templates:data||[]})}
