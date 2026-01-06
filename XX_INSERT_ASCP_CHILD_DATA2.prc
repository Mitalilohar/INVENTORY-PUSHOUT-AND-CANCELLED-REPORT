/* Formatted on 2025/09/10 12:26 (Formatter Plus v4.8.8) */
CREATE OR REPLACE PROCEDURE apps.xx_insert_ascp_child_data2 (
   p_old_plan_id       IN   NUMBER,
   p_new_plan_id       IN   NUMBER,
   p_org_id            IN   NUMBER,
   p_plan_start_date   IN   DATE,
   p_plan_end_date     IN   DATE
)
IS
   l_err_msg   VARCHAR2 (400);
BEGIN
   DELETE FROM bolinf.xx_gtt_ascp_child_tbl3;

   DELETE FROM bolinf.xx_gtt_ascp_child_tbl2;

-------------------------------------------------------------------------
-- Step 1: Insert raw detail data into staging table (tbl3)
-------------------------------------------------------------------------
   INSERT INTO bolinf.xx_gtt_ascp_child_tbl3
               (organization_id, inventory_item_id, parent_item, child_id,
                component, end_item_usage, sr_inventory_item_id, org,
                allocated_qty, old_excess_qty, new_excess_qty)
      SELECT t1.organization_id, t1.inventory_item_id AS parent_id,
             t1.end_item AS parent_item, t1.child_id, t1.component,
             t1.end_item_usage, t1.sr_inventory_item_id, t1.org,
             t1.allocated_quantity AS allocated_qty,
             (NVL (s_new.qty, 0) + NVL (p_new.qty, 0)) AS new_excess_qty,
             (NVL (s_old.qty, 0) + NVL (p_old.qty, 0)) AS old_excess_qty
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
                     msd1.using_requirement_quantity demand_qty,
                     msi2.item_name component,
                     msi2.inventory_item_id AS child_id,
                     msi1.inventory_item_id, msi2.sr_inventory_item_id,
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
                     mfp2.end_item_usage, mfp2.allocated_quantity,
                     mss1.new_schedule_date, msi2.buyer_name,
                     mss2.new_wip_start_date, msd1.demand_id,
                     mss1.new_order_quantity supply_qty_component,
                     mss1.new_order_placement_date sugg_order_date,
                     NVL (mss1.new_ship_date, TRUNC (SYSDATE)) nbd_po,
                     mss1.new_dock_date, mss1.order_number supply_order,
                     msd1.organization_id organization_id
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
                 AND msd1.plan_id = p_old_plan_id
                 AND msd1.organization_id =
                                          NVL (p_org_id, msd1.organization_id)
                 --AND msi2.inventory_item_id = :p_item_child
                 --and msi1.inventory_item_id = :p_item_parent
                 ---AND msi2.item_name in ('BLLD40-482','MAX10Y-782','MAX10Y-974','MAX10Z-736','BLLD40-483','BLLD40-484')
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
                                              --added for child org id check
                 --AND mfp1.supply_type <> 18
                 AND msd1.record_source IS NULL
                 --AND mss1.source_organization_id IS NULL
                 AND msd1.sr_instance_id = 1
                 AND msd1.using_requirement_quantity > 0
                 AND msi2.planning_make_buy_code IN (1, 2)
                 AND TRUNC (mss2.new_wip_start_date)
                        BETWEEN TRUNC (p_plan_start_date)
                            AND TRUNC (p_plan_end_date)
                 --AND mfp2.supply_type IN (18, 1)
                 AND mic.category_name NOT LIKE ('PRODUCT%')) t1,
             (SELECT   organization_id, inventory_item_id,
                       SUM (new_order_quantity) AS qty
                  FROM apps.msc_supplies
                 WHERE plan_id = p_new_plan_id
                   AND scheduled_demand_id = 0
                   AND order_type = 1
              GROUP BY organization_id, inventory_item_id) s_new,
             (SELECT   organization_id, inventory_item_id,
                       SUM (allocated_quantity) AS qty
                  FROM apps.msc_full_pegging
                 WHERE plan_id = p_new_plan_id
                   AND supply_type = 1
                   AND end_origination_type = -1
                   AND demand_id = -1
              GROUP BY organization_id, inventory_item_id) p_new,
             (SELECT   organization_id, inventory_item_id,
                       SUM (new_order_quantity) AS qty
                  FROM apps.msc_supplies
                 WHERE plan_id = p_old_plan_id
                   AND scheduled_demand_id = 0
                   AND order_type = 1
              GROUP BY organization_id, inventory_item_id) s_old,
             (SELECT   organization_id, inventory_item_id,
                       SUM (allocated_quantity) AS qty
                  FROM apps.msc_full_pegging
                 WHERE plan_id = p_old_plan_id
                   AND supply_type = 1
                   AND end_origination_type = -1
                   AND demand_id = -1
              GROUP BY organization_id, inventory_item_id) p_old
       WHERE s_new.organization_id(+) = t1.organization_id
         AND s_new.inventory_item_id(+) = t1.child_id
         AND p_new.organization_id(+) = t1.organization_id
         AND p_new.inventory_item_id(+) = t1.child_id
         AND s_old.organization_id(+) = t1.organization_id
         AND s_old.inventory_item_id(+) = t1.child_id
         AND p_old.organization_id(+) = t1.organization_id
         AND p_old.inventory_item_id(+) = t1.child_id;

-------------------------------------------------------------------------
-- Step 2: Aggregate data from tbl3 into final table (tbl2)
-------------------------------------------------------------------------
   INSERT INTO bolinf.xx_gtt_ascp_child_tbl2
               (organization_id, inventory_item_id, parent_item, child_id,
                component, end_item_usage, sr_inventory_item_id, org,
                allocated_qty, old_excess_qty, new_excess_qty)
      SELECT   organization_id, inventory_item_id, parent_item, child_id,
               component, MAX (end_item_usage) AS end_item_usage,
               sr_inventory_item_id, org, SUM (allocated_qty)
                                                             AS allocated_qty,
               MAX (old_excess_qty) AS old_excess_qty,
               MAX (new_excess_qty) AS new_excess_qty
          FROM bolinf.xx_gtt_ascp_child_tbl3
      GROUP BY organization_id,
               inventory_item_id,
               parent_item,
               child_id,
               component,
               sr_inventory_item_id,
               org;

   COMMIT;
EXCEPTION
   WHEN OTHERS
   THEN
      l_err_msg := SQLERRM;
      DBMS_OUTPUT.put_line ('Error occurred: ' || l_err_msg);
-- Optional: log to a custom error table
-- INSERT INTO your_error_log_table (procedure_name, error_message, error_date)
-- VALUES ('xx_insert_ascp_child_data', l_err_msg, SYSDATE);
END;
/

BEGIN
   apps.xx_insert_ascp_child_data2 (3022,
                                    8022,
                                    123,
                                    TO_DATE ('26-08-2025', 'DD-MM-YYYY'),
                                    TO_DATE ('15-09-2025', 'DD-MM-YYYY')
                                   );
END;

select * from bolinf.xx_gtt_ascp_child_tbl3

/*CREATE OR REPLACE PROCEDURE APPS.xx_insert_ascp_child_data2 (
   p_old_plan_id       IN   NUMBER,
   p_new_plan_id       IN   NUMBER,
   p_org_id            IN   NUMBER,
   p_plan_start_date   IN   DATE,
   p_plan_end_date     IN   DATE
)
IS
   l_err_msg   VARCHAR2 (400);
BEGIN
   DELETE FROM bolinf.xx_gtt_ascp_child_tbl3;

   DELETE FROM bolinf.xx_gtt_ascp_child_tbl2;

-------------------------------------------------------------------------
-- Step 1: Insert raw detail data into staging table (tbl3)
-------------------------------------------------------------------------
   INSERT INTO bolinf.xx_gtt_ascp_child_tbl3
               (organization_id, inventory_item_id, parent_item, child_id,
                component, end_item_usage, sr_inventory_item_id, org,
                allocated_qty, old_excess_qty, new_excess_qty)
      SELECT   t1.organization_id, t1.inventory_item_id AS parent_id,
               t1.end_item AS parent_item, t1.child_id, t1.component,
               t1.end_item_usage, t1.sr_inventory_item_id, t1.org,
               t1.allocated_quantity AS allocated_qty,
               (SELECT SUM (p.allocated_quantity)
                  FROM apps.msc_full_pegging p
                 WHERE p.plan_id = p_old_plan_id
                   AND p.supply_type IN (1, 18, 11)
                   AND p.end_origination_type = -1
                   AND p.demand_id = -1
                   AND p.inventory_item_id = t1.child_id
                   AND p.organization_id = t1.organization_id)
                                                           AS old_excess_qty,
               (SELECT SUM (p.allocated_quantity)
                  FROM apps.msc_full_pegging p
                 WHERE p.plan_id = p_new_plan_id
                   AND p.supply_type IN (1, 18, 11)
                   AND p.end_origination_type = -1
                   AND p.demand_id = -1
                   AND p.inventory_item_id = t1.child_id
                   AND p.organization_id = t1.organization_id)
                                                           AS new_excess_qty
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
                           AND mtp.partner_id = msd1.customer_id)
                                                                customer_name,
                       msd1.using_requirement_quantity demand_qty,
                       msi2.item_name component,
                       msi2.inventory_item_id AS child_id,
                       msi1.inventory_item_id, msi2.sr_inventory_item_id,
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
                           AND mtp.sr_tp_id = mss1.organization_id)
                                                                   buying_org,
                       mfp2.end_item_usage, mfp2.allocated_quantity,
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
                       msd1.organization_id organization_id
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
                   AND msd1.plan_id = p_old_plan_id
                   AND msd1.organization_id =
                                          NVL (p_org_id, msd1.organization_id)
                   --AND msi2.inventory_item_id = :p_item_child
                   --and msi1.inventory_item_id = :p_item_parent
                   ---AND msi2.item_name in ('BLLD40-482','MAX10Y-782','MAX10Y-974','MAX10Z-736','BLLD40-483','BLLD40-484')
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
                   AND msd1.organization_id =
                            msi2.organization_id
                                                --added for child org id check
                   --AND mfp1.supply_type <> 18
                   AND msd1.record_source IS NULL
                   --AND mss1.source_organization_id IS NULL
                   AND msd1.sr_instance_id = 1
                   AND msd1.using_requirement_quantity > 0
                   AND msi2.planning_make_buy_code IN (1, 2)
                   AND TRUNC (mss2.new_wip_start_date)
                          BETWEEN TRUNC (p_plan_start_date)
                              AND TRUNC (p_plan_end_date)
                   --AND mfp2.supply_type IN (18, 1)
                   AND mic.category_name NOT LIKE ('PRODUCT%')) t1;

-------------------------------------------------------------------------
-- Step 2: Aggregate data from tbl3 into final table (tbl2)
-------------------------------------------------------------------------
   INSERT INTO bolinf.xx_gtt_ascp_child_tbl2
               (organization_id, inventory_item_id, parent_item, child_id,
                component, end_item_usage, sr_inventory_item_id, org,
                allocated_qty, old_excess_qty, new_excess_qty)
      SELECT   organization_id, inventory_item_id, parent_item, child_id,
               component, MAX (end_item_usage) AS end_item_usage,
               sr_inventory_item_id, org, SUM (allocated_qty)
                                                             AS allocated_qty,
               MAX (old_excess_qty) AS old_excess_qty,
               MAX (new_excess_qty) AS new_excess_qty
          FROM bolinf.xx_gtt_ascp_child_tbl3
      GROUP BY organization_id,
               inventory_item_id,
               parent_item,
               child_id,
               component,
               sr_inventory_item_id,
               org;

   COMMIT;
EXCEPTION
   WHEN OTHERS
   THEN
      l_err_msg := SQLERRM;
      DBMS_OUTPUT.put_line ('Error occurred: ' || l_err_msg);
-- Optional: log to a custom error table
-- INSERT INTO your_error_log_table (procedure_name, error_message, error_date)
-- VALUES ('xx_insert_ascp_child_data', l_err_msg, SYSDATE);
END;
/

*/