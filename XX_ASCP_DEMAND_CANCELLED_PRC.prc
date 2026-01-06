CREATE OR REPLACE PROCEDURE APPS.xx_ascp_demand_cancelled_prc (
   p_old_plan_id   IN   NUMBER,
   p_new_plan_id   IN   NUMBER,
   p_org_id        IN   NUMBER DEFAULT NULL
) 
IS
BEGIN
   BEGIN
      DELETE FROM bolinf.xx_gtt_ascp_old_dc_tbl;

      INSERT INTO bolinf.xx_gtt_ascp_old_dc_tbl
                  (org_id, component, allocated_qty, inventory_item_id,
                   sr_inventory_item_id)
         SELECT   organization_id, component,
                  SUM (allocated_quantity) AS allocated_qty,
                  inventory_item_id, sr_inventory_item_id
             FROM (SELECT   (SELECT organization_code
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
                                AND designator_id =
                                                   msd1.schedule_designator_id)
                                                                forecast_name,
                            msd1.order_number,
                            (SELECT partner_name
                               FROM apps.msc_trading_partners mtp
                              WHERE mtp.sr_instance_id = 1
                                AND mtp.partner_type = 2
                                AND mtp.partner_id = msd1.customer_id)
                                                                customer_name,
                            msd1.using_requirement_quantity demand_qty,
                            msi2.item_name component, msi2.inventory_item_id,
                            msi2.sr_inventory_item_id,
                            mic.category_name component_category,
                            DECODE
                               (msi1.planning_make_buy_code,
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
                        --AND msi2.item_name = :p_item_name
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
                        AND mfp1.supply_type <> 18
                        AND msd1.record_source IS NULL
                        --AND mss1.source_organization_id IS NULL
                        AND msd1.sr_instance_id = 1
                        AND msd1.using_requirement_quantity > 0
                        AND msi2.planning_make_buy_code IN (1, 2)
                        AND msd1.organization_id =
                                          NVL (p_org_id, msd1.organization_id)
                        /*AND TRUNC (mss2.new_wip_start_date)
                               BETWEEN TRUNC ((SELECT MAX (plan_start_date)
                                                 FROM apps.msc_plans
                                                WHERE plan_id = p_plan_id))
                                   AND TRUNC (NVL
                                                 (p_date,
                                                    (SELECT MAX (plan_start_date)
                                                       FROM apps.msc_plans
                                                      WHERE plan_id = p_plan_id)
                                                  + 56
                                                 )
                                             )*/
                        AND mfp2.supply_type IN (3, 5,11)
                        AND mic.category_name LIKE ('PRODUCT%')
                   --AND TRUNC (msd1.using_assembly_demand_date) <= :Start_Date
                   ORDER BY msd1.using_assembly_demand_date,
                            msd1.inventory_item_id,
                            msd1.organization_id,
                            mfp1.pegging_id,
                            mfp2.pegging_id)
         GROUP BY organization_id,
                  component,
                  inventory_item_id,
                  sr_inventory_item_id
         ORDER BY component DESC;
   END;

   BEGIN
      DELETE FROM bolinf.xx_gtt_ascp_new_dc_tbl;

      INSERT INTO bolinf.xx_gtt_ascp_new_dc_tbl
                  (org_id, component, allocated_qty, inventory_item_id,
                   sr_inventory_item_id)
         SELECT   organization_id, component,
                  SUM (allocated_quantity) AS allocated_qty,
                  inventory_item_id, sr_inventory_item_id
             FROM (SELECT   (SELECT organization_code
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
                                AND designator_id =
                                                   msd1.schedule_designator_id)
                                                                forecast_name,
                            msd1.order_number,
                            (SELECT partner_name
                               FROM apps.msc_trading_partners mtp
                              WHERE mtp.sr_instance_id = 1
                                AND mtp.partner_type = 2
                                AND mtp.partner_id = msd1.customer_id)
                                                                customer_name,
                            msd1.using_requirement_quantity demand_qty,
                            msi2.item_name component, msi2.inventory_item_id,
                            msi2.sr_inventory_item_id,
                            mic.category_name component_category,
                            DECODE
                               (msi1.planning_make_buy_code,
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
                        AND msd1.plan_id = p_new_plan_id
                        --AND msi2.item_name = :p_item_name
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
                        AND mfp1.supply_type <> 18
                        AND msd1.record_source IS NULL
                        --AND mss1.source_organization_id IS NULL
                        AND msd1.sr_instance_id = 1
                        AND msd1.using_requirement_quantity > 0
                        AND msi2.planning_make_buy_code IN (1, 2)
                        AND msd1.organization_id =
                                          NVL (p_org_id, msd1.organization_id)
                        /*AND TRUNC (mss2.new_wip_start_date)
                               BETWEEN TRUNC ((SELECT MAX (plan_start_date)
                                                 FROM apps.msc_plans
                                                WHERE plan_id = p_plan_id))
                                   AND TRUNC (NVL
                                                 (p_date,
                                                    (SELECT MAX (plan_start_date)
                                                       FROM apps.msc_plans
                                                      WHERE plan_id = p_plan_id)
                                                  + 56
                                                 )
                                             )*/
                        AND mfp2.supply_type IN (3, 5,11)
                        AND mic.category_name LIKE ('PRODUCT%')
                   --AND TRUNC (msd1.using_assembly_demand_date) <= :Start_Date
                   ORDER BY msd1.using_assembly_demand_date,
                            msd1.inventory_item_id,
                            msd1.organization_id,
                            mfp1.pegging_id,
                            mfp2.pegging_id)
         GROUP BY organization_id,
                  component,
                  inventory_item_id,
                  sr_inventory_item_id
         ORDER BY component DESC;
   END;

   COMMIT;
EXCEPTION
   WHEN OTHERS
   THEN
      fnd_file.put_line (fnd_file.LOG,
                         'Error in xx_ascp_demand_cancelled_prc: ' || SQLERRM
                        );
END;
/



BEGIN
   apps.xx_ascp_demand_cancelled_prc(3022,8022,157);
END;


 SELECT allocated_qty
        FROM bolinf.xx_gtt_ascp_old_dc_tbl
       WHERE inventory_item_id = :p_inventory_item_id AND org_id = :p_org_id


 SELECT allocated_qty
        FROM bolinf.xx_gtt_ascp_new_dc_tbl
       WHERE inventory_item_id = :p_inventory_item_id AND org_id = :p_org_id

SELECT NVL (SUM (f.transaction_quantity), 0)
        FROM apps.mtl_material_transactions@srs_prod.udp.sml.com f
       WHERE f.transaction_type_id IN (44)
         AND f.operation_seq_num = 50
         AND f.inventory_item_id = :p_sr_item_id
         AND f.organization_id = :p_org_id
         AND TRUNC (f.transaction_date) BETWEEN (SELECT TRUNC (plan_start_date)
                                                   FROM apps.msc_plans
                                                  WHERE plan_id =
                                                                 :p_old_plan_id)
                                            AND (SELECT TRUNC (plan_start_date)
                                                   FROM apps.msc_plans
                                                  WHERE plan_id =
                                                                 :p_new_plan_id)