CREATE OR REPLACE PROCEDURE APPS.xx_insert_old_child_test (
   p_old_plan_id   IN   NUMBER,
   p_org_id        IN   NUMBER,
   p_old_start_date   IN   DATE,
   p_old_end_date     in   DATE
)
IS
   --v_start_date   DATE;
BEGIN
  /* SELECT MAX (plan_start_date)
     INTO v_start_date
     FROM apps.msc_plans
    WHERE plan_id = p_old_plan_id; */

   -- Step 1: Delete existing rows from the GTT
   DELETE FROM bolinf.xx_old_plan_child_test;

   -- Step 2: Insert aggregated data into GTT
   INSERT INTO bolinf.xx_old_plan_child_test
               (org, organization_id, parent_id, end_item, component,
                child_id, component_category, allocated_quantity,
                new_wip_start_date, child_sr_id, under_8wk_allocated_qty,
                above_8wk_allocated_qty, onhand_qty, po_qty)
      SELECT   org, organization_id, parent_id, end_item, component, child_id,
               component_category, SUM (allocated_quantity),
               MAX (new_wip_start_date) AS new_wip_start_date, child_sr_id,
               NVL
                  (SUM
                      (CASE
                          WHEN TRUNC (new_wip_start_date)
                                 BETWEEN TRUNC (p_old_start_date)
                                     AND TRUNC (p_old_end_date)
                             THEN allocated_quantity
                          ELSE 0
                       END
                      ),
                   0
                  ) AS under_8wk_allocated_qty,
               NVL
                  (SUM
                      (CASE
                          WHEN TRUNC (new_wip_start_date) >
                                 TRUNC(p_old_end_date)
                             THEN allocated_quantity
                          ELSE 0
                       END
                      ),
                   0
                  ) AS above_8wk_allocated_qty,
               NVL ((SELECT SUM (ms.new_order_quantity)
                       FROM apps.msc_supplies ms
                      WHERE ms.plan_id = p_old_plan_id
                        AND ms.order_type = 18
                        AND ms.organization_id = main.organization_id
                        AND ms.inventory_item_id = main.child_id),
                    0
                   ) AS onhand_qty,
               NVL ((SELECT SUM (ms.new_order_quantity)
                       FROM apps.msc_supplies ms
                      WHERE ms.plan_id = p_old_plan_id
                        AND ms.order_type IN (1, 11)
                        AND ms.organization_id = main.organization_id
                        AND ms.inventory_item_id = main.child_id),
                    0
                   ) AS po_qty
          FROM (
                -- INNER DATASET (unchanged logic, includes new_wip_start_date for internal computation)
                SELECT (SELECT organization_code
                          FROM apps.msc_trading_partners mtp
                         WHERE partner_type = 3
                           AND sr_instance_id = 1
                           AND mtp.sr_tp_id = msd1.organization_id) org,
                       msd1.organization_id,
                       msi1.inventory_item_id AS parent_id,
                       msi1.item_name AS end_item,
                       msi2.item_name AS component,
                       msi2.inventory_item_id AS child_id,
                       mic.category_name AS component_category,
                       mfp2.allocated_quantity, mss2.new_wip_start_date,
                       msi2.sr_inventory_item_id AS child_sr_id
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
                   AND msd1.plan_id = p_old_plan_id
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
                   AND msd1.sr_instance_id = 1
                   AND msd1.using_requirement_quantity > 0
                   AND msi2.planning_make_buy_code IN (1, 2)
--        AND TRUNC(mss2.new_wip_start_date) >=
--            TRUNC((SELECT MAX(plan_start_date)
--                   FROM apps.msc_plans
--                  WHERE plan_id = p_old_plan_id))
                   AND mfp2.supply_type IN (18,1,11,12,8)
                   AND mic.category_name NOT LIKE ('PRODUCT%')
                   AND msd1.organization_id =
                                          NVL (p_org_id, msd1.organization_id)) main
      GROUP BY org,
               organization_id,
               parent_id,
               end_item,
               component,
               child_id,
               component_category,
               child_sr_id;

   COMMIT;
EXCEPTION
   WHEN OTHERS
   THEN
      -- v_error_msg := 'Procedure xx_insert_old_child_test failed: ' || SQLERRM;
      DBMS_OUTPUT.put_line (   'Procedure xx_insert_old_child_test failed: '
                            || SQLERRM
                           );
      NULL;
END;
/



BEGIN
   apps.xx_insert_old_child_test (3022, 727);
END;

CREATE OR REPLACE PROCEDURE APPS.xx_insert_new_child_test (
   p_new_plan_id   IN   NUMBER,
   p_org_id        IN   NUMBER,
   p_new_start_date   IN   DATE,
   p_new_end_date     in   DATE
)
IS
  -- v_start_date   DATE;
BEGIN
   -- Get the plan start date
  /* SELECT MAX (plan_start_date)
     INTO v_start_date
     FROM apps.msc_plans
    WHERE plan_id = p_new_plan_id;*/

   -- Delete existing rows
   DELETE FROM bolinf.xx_new_plan_child_test;

   -- Insert new records
   INSERT INTO bolinf.xx_new_plan_child_test
               (org, organization_id, parent_id, end_item, component,
                child_id, component_category, allocated_quantity,
                new_wip_start_date, child_sr_id, under_8wk_allocated_qty,
                above_8wk_allocated_qty)
      SELECT   org, organization_id, parent_id, end_item, component, child_id,
               component_category, SUM (allocated_quantity),
               MAX (new_wip_start_date) AS new_wip_start_date, child_sr_id,
               NVL
                  (SUM
                      (CASE
                          WHEN TRUNC (new_wip_start_date)
                                 BETWEEN TRUNC (p_new_start_date)
                                     AND TRUNC(p_new_end_date)
                             THEN allocated_quantity
                          ELSE 0
                       END
                      ),
                   0
                  ) AS under_8wk_allocated_qty,
               NVL
                  (SUM
                      (CASE
                          WHEN TRUNC (new_wip_start_date) >
                                 TRUNC(p_new_end_date)
                             THEN allocated_quantity
                          ELSE 0
                       END
                      ),
                   0
                  ) AS above_8wk_allocated_qty
          FROM (SELECT (SELECT organization_code
                          FROM apps.msc_trading_partners mtp
                         WHERE partner_type = 3
                           AND sr_instance_id = 1
                           AND mtp.sr_tp_id = msd1.organization_id) org,
                       msd1.organization_id,
                       msi1.inventory_item_id AS parent_id,
                       msi1.item_name AS end_item,
                       msi2.item_name AS component,
                       msi2.inventory_item_id AS child_id,
                       mic.category_name AS component_category,
                       mfp2.allocated_quantity, mss2.new_wip_start_date,
                       msi2.sr_inventory_item_id AS child_sr_id
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
                   AND msd1.plan_id = p_new_plan_id
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
                   AND msd1.sr_instance_id = 1
                   AND msd1.using_requirement_quantity > 0
                   AND msi2.planning_make_buy_code IN (1, 2)
                   AND mfp2.supply_type IN (18,1,11,12,8)
                   AND mic.category_name NOT LIKE ('PRODUCT%')
                   AND msd1.organization_id =
                                          NVL (p_org_id, msd1.organization_id))
      GROUP BY org,
               organization_id,
               parent_id,
               end_item,
               component,
               child_id,
               component_category,
               child_sr_id;

   COMMIT;
EXCEPTION
   WHEN OTHERS
   THEN
      DBMS_OUTPUT.put_line (   'Procedure xx_insert_new_child_test failed: '
                            || SQLERRM
                           );
      NULL;                                         -- Log or handle as needed
END;
/
