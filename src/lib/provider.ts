import 'server-only';
export type SendInput={to:string;templateName:string;languageCode:string;parameters?:string[];idempotencyKey:string};
export type SendResult={provider:string;messageId:string;raw:unknown};
export interface WhatsAppProvider{sendTemplate(input:SendInput):Promise<SendResult>}
class MockProvider implements WhatsAppProvider{async sendTemplate(input:SendInput){return{provider:'mock',messageId:`mock-${input.idempotencyKey}`,raw:{accepted:true,to:input.to}}}}
class HttpProvider implements WhatsAppProvider{async sendTemplate(input:SendInput){const base=process.env.WHATSAPP_API_BASE_URL,token=process.env.WHATSAPP_API_TOKEN;if(!base||!token)throw new Error('Provider credentials are missing');const r=await fetch(base,{method:'POST',headers:{authorization:`Bearer ${token}`,'content-type':'application/json','idempotency-key':input.idempotencyKey},body:JSON.stringify(input)});const raw=await r.json().catch(()=>({}));if(!r.ok)throw new Error(`Provider error ${r.status}: ${JSON.stringify(raw)}`);const messageId=(raw as {messageId?:string;id?:string}).messageId||(raw as {id?:string}).id;if(!messageId)throw new Error('Provider did not return a message id');return{provider:'http',messageId,raw}}}
export function getWhatsAppProvider():WhatsAppProvider{return process.env.WHATSAPP_PROVIDER==='http'?new HttpProvider():new MockProvider()}
