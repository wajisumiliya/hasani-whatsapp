'use client';import {createClient} from '@supabase/supabase-js';
export function getBrowserClient(){const url=process.env.NEXT_PUBLIC_SUPABASE_URL,key=process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;if(!url||!key)throw new Error('Supabase browser environment is not configured');return createClient(url,key);}
