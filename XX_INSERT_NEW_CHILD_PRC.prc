/* Formatted on 2025/09/15 17:39 (Formatter Plus v4.8.8) */
CREATE OR REPLACE PROCEDURE apps.xx_insert_new_child_prc (
   p_new_plan_id   IN   NUMBER,
   p_new_plan_start_date          IN   DATE,
   p_org_id        IN   NUMBER
)
IS
   v_error_msg             VARCHAR2 (4000);
   v_max_plan_start_date   DATE;
BEGIN
   -- Step 1: Delete existing rows
   DELETE FROM bolinf.xx_new_plan_child_gtt;

   -- Step 2: Get max plan start date once
   SELECT MAX (plan_start_date)
     INTO v_max_plan_start_date
     FROM apps.msc_plans
    WHERE plan_id = p_new_plan_id;

   -- Step 3: Insert new data with optimized query using implicit joins
   INSERT INTO bolinf.xx_new_plan_child_gtt
               (org, organization_id, parent_id, end_item, order_type,
                component, child_id, component_category, supply_type,
                allocated_quantity, new_wip_start_date, child_sr_id)
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
             msi2.sr_inventory_item_id AS child_sr_id
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
         AND msd1.plan_id = p_new_plan_id
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
      v_error_msg := 'Procedure xx_insert_new_child_prc failed: ' || SQLERRM;
      DBMS_OUTPUT.put_line (v_error_msg);
END;
/


select * from bolinf.xx_new_plan_child_gtt

BEGIN
   -- Full allocation snapshot from OLD plan
   apps.xx_insert_new_child_prc (8022,
                                 TO_DATE ('30-09-2025', 'DD-MM-YYYY'),
                                 727
                                );
END;

/*CREATE OR REPLACE PROCEDURE APPS.xx_insert_new_child_prc (
   p_new_plan_id   IN   NUMBER,
   p_org_id        IN   NUMBER
)
IS
   v_error_msg   VARCHAR2 (4000);
BEGIN
   -- Step 1: Delete existing rows
   DELETE FROM bolinf.xx_new_plan_child_gtt;

   -- Step 2: Insert new data
   INSERT INTO bolinf.xx_new_plan_child_gtt
               (org, organization_id, parent_id, end_item, order_type,
                component, child_id, component_category, supply_type,
                allocated_quantity, new_wip_start_date, child_sr_id)
      SELECT org, organization_id, parent_id, end_item, order_type,
             component, inventory_item_id AS child_id, component_category,
             supply_type, allocated_quantity, new_wip_start_date,
             child_sr_id
        FROM (SELECT (SELECT organization_code
                        FROM apps.msc_trading_partners mtp
                       WHERE partner_type = 3
                         AND sr_instance_id = 1
                         AND mtp.sr_tp_id = msd1.organization_id) org,
                     msd1.using_assembly_demand_date demand_date,
                     DECODE (msd1.origination_type,
                             30, 'Sales_Order',
                             29, 'Forecast'
                            ) order_type,
                     msi1.item_name end_item,
                     mic1.category_name category_name_end_item,
                     (SELECT designator
                        FROM apps.msc_designators
                       WHERE sr_instance_id = 1
                         AND organization_id = msd1.organization_id
                         AND designator_id = msd1.schedule_designator_id)
                                                                forecast_name,
                     msd1.order_number,
                     (SELECT partner_name
                        FROM apps.msc_trading_partners mtp
                       WHERE mtp.sr_instance_id = 1
                         AND mtp.partner_type = 2
                         AND mtp.partner_id = msd1.customer_id) customer_name,
                     msd1.using_requirement_quantity demand_qty,
                     msi2.item_name component, msi2.inventory_item_id,
                     mic.category_name component_category,
                     DECODE (msi1.planning_make_buy_code,
                             1, 'Make',
                             2, 'Buy'
                            ) end_item_make_buy,
                     DECODE (msi2.planning_make_buy_code,
                             1, 'Make',
                             2, 'Buy'
                            ) make_buy,
                     DECODE (mfp2.supply_type,
                             1, 'Purchase order',
                             2, 'Purchase requisition',
                             3, 'Work Order',
                             5, 'Planned order',
                             18, 'Onhand',
                             11, 'Intransit shipment',
                             12, 'Intransit receipt',
                             8, 'PO in receiving'
                            ) supply_type,
                     (SELECT organization_code
                        FROM apps.msc_trading_partners mtp
                       WHERE partner_type = 3
                         AND sr_instance_id = 1
                         AND mtp.sr_tp_id = mss1.organization_id) buying_org,
                     mfp2.allocated_quantity, mfp2.end_item_usage,
                     mss1.new_schedule_date, msi2.buyer_name,
                     mss2.new_wip_start_date, msd1.demand_id,
                     mss1.new_order_quantity supply_qty_component,
                     mss1.new_order_placement_date sugg_order_date,
                     NVL (mss1.new_ship_date, TRUNC (SYSDATE)) nbd_po,
                     mss1.new_dock_date,
                     (SELECT ROUND (item_cost, 2)
                        FROM apps.cst_item_costs@srs_prod
                       WHERE inventory_item_id =
                                          msi2.sr_inventory_item_id
                         AND organization_id = msi2.organization_id
                         AND cost_type_id = 2) item_cost,
                     mss1.order_number supply_order,
                     msd1.organization_id organization_id,
                     msi2.sr_inventory_item_id AS child_sr_id,
                     msi1.inventory_item_id AS parent_id
                FROM apps.msc_demands msd1,
                     apps.msc_item_categories mic,
                     apps.msc_system_items msi1,
                     apps.msc_full_pegging mfp1,
                     apps.msc_full_pegging mfp2,
                     apps.msc_system_items msi2,
                     apps.msc_supplies mss1,
                     apps.msc_supplies mss2,
                     apps.msc_item_categories mic1
               WHERE msd1.plan_id = mfp1.plan_id
                 AND msd1.sr_instance_id = mfp1.sr_instance_id
                 AND msd1.inventory_item_id = mfp1.inventory_item_id
                 AND msd1.organization_id = mfp1.organization_id
                 AND msd1.demand_id = mfp1.demand_id
--AND msi1.item_name IN ('E3PD14-044-986')
                 AND msd1.plan_id = p_new_plan_id
--AND msi2.item_name = :p_item_name
--AND msi2.item_name in ('BLLD40-482','MAX10Y-782','MAX10Y-974','MAX10Z-736','BLLD40-483','BLLD40-484')
--AND mic1.category_name like '%ELITE 500%'
                 AND msi2.inventory_item_id = mic.inventory_item_id
                 AND msi2.organization_id = mic.organization_id
                 AND msi2.sr_instance_id = mic.sr_instance_id
                 AND mic.category_set_id = 16
                 AND msi1.inventory_item_id = mic1.inventory_item_id
                 AND msi1.organization_id = mic1.organization_id
                 AND msi1.sr_instance_id = mic1.sr_instance_id
                 AND mic1.category_set_id = 16
                 AND msd1.plan_id = msi1.plan_id
                 AND msd1.sr_instance_id = msi1.sr_instance_id
                 AND msd1.inventory_item_id = msi1.inventory_item_id
                 AND msd1.organization_id = msi1.organization_id
                 AND mfp1.plan_id = mfp2.plan_id
                 AND mfp1.sr_instance_id = mfp2.sr_instance_id
                 AND mfp1.pegging_id = mfp2.end_pegging_id
                 AND mfp2.plan_id = msi2.plan_id
                 AND mfp2.sr_instance_id = msi2.sr_instance_id
                 AND mfp2.inventory_item_id = msi2.inventory_item_id
                 AND mfp2.organization_id = msi2.organization_id
                 AND mfp2.plan_id = mss1.plan_id
                 AND mfp2.sr_instance_id = mss1.sr_instance_id
                 AND mfp2.transaction_id = mss1.transaction_id
                 AND mfp1.plan_id = mss2.plan_id
                 AND mfp1.transaction_id = mss2.transaction_id
                 AND msd1.organization_id = msi2.organization_id
                 AND mfp1.supply_type <> 18
                 AND msd1.record_source IS NULL
--AND mss1.source_organization_id IS NULL
                 AND msd1.sr_instance_id = 1
                 AND msd1.using_requirement_quantity > 0
                 AND msi2.planning_make_buy_code IN (1, 2)
                 AND TRUNC (mss2.new_wip_start_date) >=
                                       TRUNC ((SELECT MAX (plan_start_date)
                                                 FROM apps.msc_plans
                                                WHERE plan_id = p_new_plan_id))
                 AND mfp2.supply_type IN (18, 1,8,11,12)
                 AND mic.category_name NOT LIKE ('PRODUCT%')
--  AND msi2.inventory_item_id = :p_item_id
                 AND msd1.organization_id =
                                          NVL (p_org_id, msd1.organization_id));

   COMMIT;
EXCEPTION
   WHEN OTHERS
   THEN
      v_error_msg := 'Procedure xx_insert_new_child_prc failed: ' || SQLERRM;
      DBMS_OUTPUT.put_line (v_error_msg);
END;
/
*/