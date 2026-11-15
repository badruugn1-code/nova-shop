DO $patch$
DECLARE original text; updated text; start_pos integer; end_pos integer;
BEGIN
 SELECT pg_get_functiondef('public.reserve_shop_order_stock()'::regprocedure) INTO original;
 start_pos:=strpos(original,'if new.promo_code is not null');
 end_pos:=strpos(original,'if calculated_total<>new.total_mnt');
 IF start_pos=0 OR end_pos<=start_pos THEN RAISE EXCEPTION 'Unexpected stock function definition'; END IF;
 updated:=substr(original,1,start_pos-1)||$discount$
 declare pct integer:=0; vip integer:=0;
 begin
  if auth.uid() is not null and new.customer_id=auth.uid() then
   select case when coalesce(m.points,0)>=s.gold_points then greatest(0,least(50,s.gold_discount))
    when coalesce(m.points,0)>=s.silver_points then greatest(0,least(50,s.silver_discount)) else 0 end
   into vip from public.shop_vip_settings s left join public.shop_vip_members m on m.user_id=auth.uid() where s.id=1;
  end if;
  if new.promo_code is not null and btrim(new.promo_code)<>'' then
   select discount_percent into pct from public.shop_promos where upper(code)=upper(btrim(new.promo_code)) and active=true limit 1;
   if pct is null then raise exception 'Хямдралын код буруу эсвэл идэвхгүй'; end if;
   new.promo_code:=upper(btrim(new.promo_code));
  end if;
  calculated_total:=calculated_total-floor(calculated_total*greatest(coalesce(vip,0),coalesce(pct,0))/100.0)::bigint;
 end;
 $discount$||substr(original,end_pos);
 -- Acquire product locks consistently to reduce deadlocks between multi-product orders.
 updated:=replace(updated,'select value from jsonb_array_elements(new.items) loop','select value from jsonb_array_elements(new.items) order by value->>''id'' loop');
 EXECUTE updated;
END $patch$;