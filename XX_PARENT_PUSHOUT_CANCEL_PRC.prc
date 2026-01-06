CREATE OR REPLACE PROCEDURE APPS.xx_parent_pushout_cancel_prc (
   p_old_plan_id   IN NUMBER,
   p_new_plan_id   IN NUMBER,
   p_org_id        IN NUMBER DEFAULT NULL
)
IS
BEGIN
   -- Clean staging table
   DELETE FROM bolinf.xx_pushout_cancel_stg;

   -- Insert data with optimized joins for pushout and cancelled demand
   INSERT INTO bolinf.xx_pushout_cancel_stg (
      inventory_item_id,
      org_id,
      sr_inventory_item_id,
      allocated_qty,
      cancelled_qty
   )
   SELECT
      o.inventory_item_id,
      o.org_id,
      o.sr_inventory_item_id,

      -- Pushout allocated qty
      NVL(apps.xx_get_pushout_qty_func(
         o.inventory_item_id,
         p_old_plan_id,
         p_new_plan_id,
         nvl(o.allocated_qty,0),
         nvl(n.allocated_qty,0),
         o.org_id,
         o.sr_inventory_item_id
      ), 0) AS allocated_qty,

      -- Cancelled demand qty
      apps.xx_get_demand_cancelled(
         o.inventory_item_id,
         p_old_plan_id,
         p_new_plan_id,
         o.org_id,
         o.sr_inventory_item_id
      ) AS cancelled_qty

   FROM bolinf.xx_gtt_ascp_old_tbl o
   LEFT JOIN bolinf.xx_gtt_ascp_new_tbl n
     ON o.inventory_item_id = n.inventory_item_id
    AND o.org_id = n.org_id
   WHERE o.org_id = NVL(p_org_id, o.org_id);

   COMMIT;

EXCEPTION
   WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.LOG,
         'Error in xx_parent_pushout_cancel_prc: ' || SQLERRM);
      ROLLBACK;
END xx_parent_pushout_cancel_prc ;
/


select * from bolinf.xx_pushout_cancel_stg where inventory_item_id=86033

begin

apps.xx_parent_pushout_cancel_prc (3022,8022,727);

end;


CREATE OR REPLACE PROCEDURE APPS.xx_parent_pushout_cancel_prc (
   p_old_plan_id   IN NUMBER,
   p_new_plan_id   IN NUMBER,
   p_org_id        IN NUMBER DEFAULT NULL
)
IS
   v_wip_quantity NUMBER;
BEGIN
   -- Clean staging table
   DELETE FROM bolinf.xx_pushout_cancel_stg;

   -- Insert data with WIP quantity
   INSERT INTO bolinf.xx_pushout_cancel_stg (
      inventory_item_id,
      org_id,
      sr_inventory_item_id,
      allocated_qty,
      old_excess_qty,
      cancelled_qty
   )
   SELECT
    o.inventory_item_id,
    o.org_id,
    o.sr_inventory_item_id,

    -- WIP quantity calculated once
    NVL((
        SELECT SUM(f.transaction_quantity)
        FROM apps.mtl_material_transactions@srs_prod.udp.sml.com f
        WHERE f.transaction_type_id = 44
          AND f.operation_seq_num = 50
          AND f.inventory_item_id = o.sr_inventory_item_id
          AND f.organization_id = o.org_id
          AND TRUNC(f.transaction_date) BETWEEN
              (SELECT TRUNC(plan_start_date)
               FROM apps.msc_plans
               WHERE plan_id = p_old_plan_id)
              AND
              (SELECT TRUNC(plan_start_date)
               FROM apps.msc_plans
               WHERE plan_id = p_new_plan_id)
    ), 0) AS wip_quantity,

    -- Pushout allocated qty (pass WIP qty here)
    NVL(apps.xx_get_pushout_qty_func1(
        o.allocated_qty,
        n.allocated_qty,
        NVL((
            SELECT SUM(f.transaction_quantity)
            FROM apps.mtl_material_transactions@srs_prod.udp.sml.com f
            WHERE f.transaction_type_id = 44
              AND f.operation_seq_num = 50
              AND f.inventory_item_id = o.sr_inventory_item_id
              AND f.organization_id = o.org_id
              AND TRUNC(f.transaction_date) BETWEEN
                  (SELECT TRUNC(plan_start_date)
                   FROM apps.msc_plans
                   WHERE plan_id = p_old_plan_id)
                  AND
                  (SELECT TRUNC(plan_start_date)
                   FROM apps.msc_plans
                   WHERE plan_id = p_new_plan_id)
        ), 0)
    ), 0) AS allocated_qty,

    -- Cancelled demand qty
    apps.xx_get_demand_cancelled(
        o.inventory_item_id,
        p_old_plan_id,
        p_new_plan_id,
        o.org_id,
        o.sr_inventory_item_id
    ) AS cancelled_qty

FROM bolinf.xx_gtt_ascp_old_tbl o
LEFT JOIN bolinf.xx_gtt_ascp_new_tbl n
    ON o.inventory_item_id = n.inventory_item_id
    AND o.org_id = n.org_id
WHERE o.org_id = NVL(p_org_id, o.org_id);

   COMMIT;

EXCEPTION
   WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.LOG,
         'Error in xx_parent_pushout_cancel_prc: ' || SQLERRM);
      ROLLBACK;
END;


/* Formatted on 2025/08/11 12:25 (Formatter Plus v4.8.8) */
SELECT SUM (f.transaction_quantity)
  FROM apps.mtl_material_transactions@srs_prod.udp.sml.com f
 WHERE f.transaction_type_id = 44
   AND f.operation_seq_num = 50
   AND f.inventory_item_id = :sr_inventory_item_id
   AND f.organization_id = :org_id
   AND TRUNC (f.transaction_date) BETWEEN (SELECT TRUNC (plan_start_date)
                                             FROM apps.msc_plans
                                            WHERE plan_id = :p_old_plan_id)
                                      AND (SELECT TRUNC (plan_start_date)
                                             FROM apps.msc_plans
                                            WHERE plan_id = :p_new_plan_id)
                                            

/* Formatted on 2025/08/11 12:34 (Formatter Plus v4.8.8) */
INSERT INTO bolinf.xx_pushout_cancel_stg
            (inventory_item_id, org_id, sr_inventory_item_id, allocated_qty,
             old_excess_qty, cancelled_qty)
   SELECT DATA.inventory_item_id, DATA.org_id, DATA.sr_inventory_item_id,
          
          -- Allocated qty using WIP qty only once
          NVL
             (apps.xx_get_pushout_qty_func1 (DATA.allocated_qty,
                                             DATA.new_allocated_qty,
                                             DATA.wip_quantity
                                            ),
              0
             ) AS allocated_qty,
          
          -- WIP qty
          DATA.wip_quantity,
          
          -- Cancelled demand qty
          apps.xx_get_demand_cancelled
                                  (DATA.inventory_item_id,
                                   :p_old_plan_id,
                                   :p_new_plan_id,
                                   DATA.org_id,
                                   DATA.sr_inventory_item_id
                                  ) AS cancelled_qty
     FROM (SELECT o.inventory_item_id, o.org_id, o.sr_inventory_item_id,
                  o.allocated_qty, n.allocated_qty AS new_allocated_qty,
                  NVL
                     ((SELECT SUM (f.transaction_quantity)
                         FROM apps.mtl_material_transactions@srs_prod.udp.sml.com f
                        WHERE f.transaction_type_id = 44
                          AND f.operation_seq_num = 50
                          AND f.inventory_item_id = o.sr_inventory_item_id
                          AND f.organization_id = o.org_id
                          AND TRUNC (f.transaction_date)
                                 BETWEEN (SELECT TRUNC (plan_start_date)
                                            FROM apps.msc_plans
                                           WHERE plan_id = :p_old_plan_id)
                                     AND (SELECT TRUNC (plan_start_date)
                                            FROM apps.msc_plans
                                           WHERE plan_id = :p_new_plan_id)),
                      0
                     ) AS wip_quantity
             FROM bolinf.xx_gtt_ascp_old_tbl o LEFT JOIN bolinf.xx_gtt_ascp_new_tbl n
                  ON o.inventory_item_id = n.inventory_item_id
                AND o.org_id = n.org_id
                  ) DATA
    WHERE DATA.org_id = NVL (:org_id, DATA.org_id)
    
select * from bolinf.xx_pushout_cancel_stg where sr_inventory_item_id=2008943