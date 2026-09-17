export type PhoneResult={input:string;phone:string|null;valid:boolean;reason?:string};
export function normalizeMalaysiaPhone(value:unknown):PhoneResult{
 const input=String(value??'').trim(); let n=input.replace(/[^0-9+]/g,'');
 if(n.startsWith('+')) n=n.slice(1); if(n.startsWith('60')) n=n.slice(2); else if(n.startsWith('0')) n=n.slice(1);
 if(!/^1\d{8,9}$/.test(n)) return {input,phone:null,valid:false,reason:'Invalid Malaysian mobile number'};
 return {input,phone:`+60${n}`,valid:true};
}
