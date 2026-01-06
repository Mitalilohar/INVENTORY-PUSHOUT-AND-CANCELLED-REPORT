/* Formatted on 2025/08/11 12:18 (Formatter Plus v4.8.8) */
CREATE OR REPLACE FUNCTION apps.xx_get_pushout_qty_func1 (
   p_old_qty   IN   NUMBER,
   p_new_qty   IN   NUMBER,
   p_wip_qty   IN   NUMBER
)
   RETURN NUMBER
IS
BEGIN
   RETURN p_old_qty - p_wip_qty - p_new_qty;
EXCEPTION
   WHEN OTHERS
   THEN
      RETURN 0;
END;
/



CREATE OR REPLACE FUNCTION APPS.xx_get_pushout_qty_func (
   p_inventory_item_id   IN   NUMBER,
   p_old_plan_id         IN   NUMBER,
   p_new_plan_id         IN   NUMBER,
   p_old_qty             IN   NUMBER,
   p_new_qty             IN   NUMBER,
   p_org_id              IN   NUMBER,
   p_sr_item_id          IN   NUMBER
)
   RETURN NUMBER
IS
   --v_inventory_item_id   NUMBER;
  -- v_old_alloc_qty     NUMBER := p_old_qty;
  -- v_new_alloc_qty     NUMBER := p_new_qty;
   v_wip_quantity      NUMBER ;
   v_final_alloc_qty   NUMBER ;
BEGIN
   -- Retrieve old allocated quantity
   /*BEGIN
      SELECT allocated_qty
        INTO v_old_alloc_qty
        FROM bolinf.xx_gtt_ascp_old_tbl
       WHERE inventory_item_id = p_inventory_item_id AND org_id = p_org_id;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         v_old_alloc_qty := 0;
   END;

   -- Retrieve new allocated quantity
   BEGIN
      SELECT allocated_qty
        INTO v_new_alloc_qty
        FROM bolinf.xx_gtt_ascp_new_tbl
       WHERE inventory_item_id = p_inventory_item_id AND org_id = p_org_id;
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         v_new_alloc_qty := 0;
   END;*/

   -- Quantity WIP discrete jobs
   BEGIN
      SELECT NVL (SUM (f.transaction_quantity), 0)
        INTO v_wip_quantity
        FROM apps.mtl_material_transactions@srs_prod f
       WHERE f.transaction_type_id IN (44)
         AND f.operation_seq_num = 50
         AND f.inventory_item_id = p_sr_item_id
         AND f.organization_id = p_org_id
         AND TRUNC (f.transaction_date) BETWEEN (SELECT TRUNC (plan_start_date)
                                                   FROM apps.msc_plans
                                                  WHERE plan_id =
                                                                 p_old_plan_id)
                                            AND (SELECT TRUNC (plan_start_date)
                                                   FROM apps.msc_plans
                                                  WHERE plan_id =
                                                                 p_new_plan_id);
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         v_wip_quantity := 0;
   END;

   -- Final calculation
   v_final_alloc_qty := p_old_qty - v_wip_quantity - p_new_qty;

  /* IF v_final_alloc_qty < 0
   THEN
      v_final_alloc_qty := 0;
   END IF;*/

   RETURN v_final_alloc_qty;
EXCEPTION
   WHEN OTHERS
   THEN
      RETURN 0;
END;
/


SELECT inventory_item_id
        FROM apps.msc_system_items
       WHERE item_name = 'SPD103-Z02*5972120' AND organization_id = 123


SELECT xx_get_allocated_qty_func(100860,3022,2022, 123,6317147) AS allocated_qty
FROM dual

