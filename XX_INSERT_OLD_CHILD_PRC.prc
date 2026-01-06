
/* Formatted on 2025/10/14 16:52 (Formatter Plus v4.8.8) */
CREATE OR REPLACE PROCEDURE apps.xx_insert_old_child_prc (
   p_old_plan_id           IN   NUMBER,
   p_new_plan_start_date   IN   DATE,
   p_org_id                IN   NUMBER
)
IS
   v_error_msg             VARCHAR2 (4000);
   v_max_plan_start_date   DATE;
BEGIN
   DELETE FROM bolinf.xx_old_plan_child_gtt;

   DELETE FROM bolinf.xx_txn_type_gtt;

   -- Step 1: Preload valid transaction type IDs from remote DB
   INSERT INTO bolinf.xx_txn_type_gtt
               (transaction_type_id)
      SELECT DISTINCT transaction_type_id
                 FROM mtl_transaction_types@srs_prod
                WHERE LOWER (transaction_type_name) NOT LIKE
                                                        'internal order pick'
                  AND LOWER (transaction_type_name) NOT LIKE '%transfer%';

   COMMIT;

   -- Step 2: Get max plan start date once
   SELECT MAX (plan_start_date)
     INTO v_max_plan_start_date
     FROM apps.msc_plans
    WHERE plan_id = p_old_plan_id;

   -- Step 3: Insert new data with optimized query using implicit joins
   INSERT INTO bolinf.xx_old_plan_child_gtt
               (org, organization_id, parent_id, end_item, order_type,
                component, child_id, component_category, supply_type,
                allocated_quantity, new_wip_start_date, child_sr_id,
                wip_issued_qty)
      SELECT mtp.organization_code AS org, msd1.organization_id,
             msi1.inventory_item_id AS parent_id, msi1.item_name AS end_item,
             DECODE (msd1.origination_type,
                     30, 'Sales_Order',
                     29, 'Forecast'
                    ) AS order_type,
             msi2.item_name AS component, msi2.inventory_item_id AS child_id,
             mic.category_name AS component_category,
             DECODE (mfp2.supply_type,
                     1, 'Purchase order',
                     2, 'Purchase requisition',
                     3, 'Work Order',
                     5, 'Planned order',
                     18, 'Onhand',
                     11, 'Intransit shipment',
                     12, 'Intransit receipt',
                     8, 'PO in receiving'
                    ) AS supply_type,
             mfp2.allocated_quantity, mss2.new_wip_start_date,
             msi2.sr_inventory_item_id AS child_sr_id,
             NVL
                ((SELECT ABS (SUM (mmt.transaction_quantity))
                    FROM mtl_material_transactions@srs_prod mmt
                   WHERE mmt.transaction_type_id IN (
                                             SELECT transaction_type_id
                                               FROM bolinf.xx_txn_type_gtt)
                     AND mmt.inventory_item_id = msi2.sr_inventory_item_id
                     AND mmt.organization_id = msd1.organization_id
                     AND mmt.transaction_quantity < 0
                     AND mmt.transaction_date
                            BETWEEN TRUNC (v_max_plan_start_date)
                                AND TRUNC (p_new_plan_start_date)),
                 0
                ) AS wip_issued_qty
        FROM apps.msc_demands msd1,
             apps.msc_full_pegging mfp1,
             apps.msc_full_pegging mfp2,
             apps.msc_system_items msi1,
             apps.msc_system_items msi2,
             apps.msc_item_categories mic,
             apps.msc_supplies mss2,
             apps.msc_trading_partners mtp
       WHERE msd1.plan_id = mfp1.plan_id
         AND msd1.sr_instance_id = mfp1.sr_instance_id
         AND msd1.inventory_item_id = mfp1.inventory_item_id
         AND msd1.organization_id = mfp1.organization_id
         AND msd1.demand_id = mfp1.demand_id
         AND mfp1.plan_id = mfp2.plan_id
         AND mfp1.sr_instance_id = mfp2.sr_instance_id
         AND mfp1.pegging_id = mfp2.end_pegging_id
         AND msd1.plan_id = msi1.plan_id
         AND msd1.sr_instance_id = msi1.sr_instance_id
         AND msd1.inventory_item_id = msi1.inventory_item_id
         AND msd1.organization_id = msi1.organization_id
         AND mfp2.plan_id = msi2.plan_id
         AND mfp2.sr_instance_id = msi2.sr_instance_id
         AND mfp2.inventory_item_id = msi2.inventory_item_id
         AND mfp2.organization_id = msi2.organization_id
         AND msd1.organization_id = msi2.organization_id
         AND msi2.inventory_item_id = mic.inventory_item_id
         AND msi2.organization_id = mic.organization_id
         AND msi2.sr_instance_id = mic.sr_instance_id
         AND mic.category_set_id = 16
         AND mfp1.plan_id = mss2.plan_id
         AND mfp1.transaction_id = mss2.transaction_id
         AND msd1.organization_id = mtp.sr_tp_id
         AND mtp.partner_type = 3
         AND mtp.sr_instance_id = 1
         AND msd1.sr_instance_id = 1
         AND msd1.plan_id = p_old_plan_id
         AND msd1.organization_id = NVL (p_org_id, msd1.organization_id)
         AND msd1.using_requirement_quantity > 0
         AND msd1.record_source IS NULL
         AND mfp1.supply_type <> 18
         AND msi2.planning_make_buy_code IN (1, 2)
         AND mfp2.supply_type IN (18, 1, 8, 11, 12)
         AND mic.category_name NOT LIKE 'PRODUCT%'
         AND TRUNC (mss2.new_wip_start_date) >= TRUNC (v_max_plan_start_date);

   COMMIT;
EXCEPTION
   WHEN OTHERS
   THEN
      v_error_msg := 'Procedure xx_insert_old_child_prc failed: ' || SQLERRM;
      DBMS_OUTPUT.put_line (v_error_msg);
      RAISE;
END;
/


/* 
CREATE OR REPLACE PROCEDURE apps.xx_insert_old_child_prc (
   p_old_plan_id   IN   NUMBER,
   p_new_plan_start_date          IN   DATE,
   p_org_id        IN   NUMBER
)
IS
   v_error_msg             VARCHAR2 (4000);
   v_max_plan_start_date   DATE;
BEGIN
   -- Step 1: Delete existing rows
   DELETE FROM bolinf.xx_old_plan_child_gtt;

   -- Step 2: Get max plan start date once
   SELECT MAX (plan_start_date)
     INTO v_max_plan_start_date
     FROM apps.msc_plans
    WHERE plan_id = p_old_plan_id;

   -- Step 3: Insert new data with optimized query using implicit joins
   INSERT INTO bolinf.xx_old_plan_child_gtt
               (org, organization_id, parent_id, end_item, order_type,
                component, child_id, component_category, supply_type,
                allocated_quantity, new_wip_start_date, child_sr_id,
                wip_issued_qty)
      SELECT mtp.organization_code AS org, msd1.organization_id,
             msi1.inventory_item_id AS parent_id, msi1.item_name AS end_item,
             DECODE (msd1.origination_type,
                     30, 'Sales_Order',
                     29, 'Forecast'
                    ) AS order_type,
             msi2.item_name AS component,
             msi2.inventory_item_id AS child_id,
             mic.category_name AS component_category,
             DECODE (mfp2.supply_type,
                     1, 'Purchase order',
                     2, 'Purchase requisition',
                     3, 'Work Order',
                     5, 'Planned order',
                     18, 'Onhand',
                     11, 'Intransit shipment',
                     12, 'Intransit receipt',
                     8, 'PO in receiving'
                    ) AS supply_type,
             mfp2.allocated_quantity, mss2.new_wip_start_date,
             msi2.sr_inventory_item_id AS child_sr_id,
             NVL
                ((SELECT ABS (SUM (mmt.transaction_quantity))
                    FROM mtl_material_transactions@srs_prod mmt
                   WHERE mmt.inventory_item_id = msi2.sr_inventory_item_id
                     AND mmt.organization_id = msd1.organization_id
                     AND mmt.transaction_quantity < 0
                     
                     AND mmt.transaction_date BETWEEN v_max_plan_start_date
                                                  AND TRUNC (p_new_plan_start_date)),
                 0
                ) AS wip_issued_qty
        FROM apps.msc_demands msd1,
             apps.msc_full_pegging mfp1,
             apps.msc_full_pegging mfp2,
             apps.msc_system_items msi1,
             apps.msc_system_items msi2,
             apps.msc_item_categories mic,
             apps.msc_supplies mss2,
             apps.msc_trading_partners mtp
       WHERE msd1.plan_id = mfp1.plan_id
         AND msd1.sr_instance_id = mfp1.sr_instance_id
         AND msd1.inventory_item_id = mfp1.inventory_item_id
         AND msd1.organization_id = mfp1.organization_id
         AND msd1.demand_id = mfp1.demand_id
         AND mfp1.plan_id = mfp2.plan_id
         AND mfp1.sr_instance_id = mfp2.sr_instance_id
         AND mfp1.pegging_id = mfp2.end_pegging_id
         AND msd1.plan_id = msi1.plan_id
         AND msd1.sr_instance_id = msi1.sr_instance_id
         AND msd1.inventory_item_id = msi1.inventory_item_id
         AND msd1.organization_id = msi1.organization_id
         AND mfp2.plan_id = msi2.plan_id
         AND mfp2.sr_instance_id = msi2.sr_instance_id
         AND mfp2.inventory_item_id = msi2.inventory_item_id
         AND mfp2.organization_id = msi2.organization_id
         AND msd1.organization_id = msi2.organization_id
         AND msi2.inventory_item_id = mic.inventory_item_id
         AND msi2.organization_id = mic.organization_id
         AND msi2.sr_instance_id = mic.sr_instance_id
         AND mic.category_set_id = 16
         AND mfp1.plan_id = mss2.plan_id
         AND mfp1.transaction_id = mss2.transaction_id
         AND msd1.organization_id = mtp.sr_tp_id
         AND mtp.partner_type = 3
         AND mtp.sr_instance_id = 1
         AND msd1.sr_instance_id = 1
         AND msd1.plan_id = p_old_plan_id
         AND msd1.organization_id = NVL (p_org_id, msd1.organization_id)
         AND msd1.using_requirement_quantity > 0
         AND msd1.record_source IS NULL
         AND mfp1.supply_type <> 18
         AND msi2.planning_make_buy_code IN (1, 2)
         AND mfp2.supply_type IN (18, 1, 8, 11, 12)
         AND mic.category_name NOT LIKE 'PRODUCT%'
         AND TRUNC (mss2.new_wip_start_date) >= TRUNC (v_max_plan_start_date);

   COMMIT;
EXCEPTION
   WHEN OTHERS
   THEN
      v_error_msg := 'Procedure xx_insert_old_child_prc failed: ' || SQLERRM;
      DBMS_OUTPUT.put_line (v_error_msg);
      RAISE;
END;


select * from bolinf.xx_old_plan_child_gtt

BEGIN
   -- Full allocation snapshot from OLD plan
   apps.xx_insert_old_child_prc (3022,
                                 TO_DATE ('30-09-2025', 'DD-MM-YYYY'),
                                 727
                                );
END;

*/