/* Formatted on 2025/12/24 16:19 (Formatter Plus v4.8.8) */
CREATE OR REPLACE PROCEDURE apps.xx_ins_pushout_cancelled_data1 (
   p_org_id           IN   NUMBER DEFAULT NULL,
   p_old_start_date   IN   DATE,
   p_new_start_date   IN   DATE,
   p_date             IN   DATE
)
IS
BEGIN
   DELETE FROM bolinf.rpt_pushout_data;

   -- Insert Pushout Data (child-level only)
   INSERT INTO bolinf.rpt_pushout_data
               (child_id, organization_id, wip_issued_qty, pushout_onhand,
                pushout_poir)
      SELECT child_id, organization_id, wip_issued_qty,
             CASE
                WHEN wip_issued_qty > 0
                   THEN (pushout_onhand - wip_issued_qty
                        )
                ELSE pushout_onhand
             END AS final_pushout_onhand,
             CASE
                WHEN wip_issued_qty > 0
                   THEN (total_pushout - wip_issued_qty
                        )
                ELSE total_pushout
             END AS final_total_pushout
        FROM (SELECT o.child_id, o.organization_id, o.wip_issued_qty,
                     NVL (o.onhand, 0) - NVL (n.onhand, 0) AS pushout_onhand,
                       NVL (o.total_pushout, 0)
                     - NVL (n.total_pushout, 0) AS total_pushout
                FROM (SELECT   child_id, organization_id, wip_issued_qty,
                               SUM
                                  (CASE
                                      WHEN supply_type IN
                                              ('Onhand', 'Intransit receipt')
                                         THEN allocated_quantity
                                      ELSE 0
                                   END
                                  ) AS onhand,
                               SUM
                                  (CASE
                                      WHEN supply_type IN
                                             ('Purchase order', 'Onhand',
                                              'Intransit shipment',
                                              'Intransit receipt',
                                              'PO in receiving')
                                         THEN allocated_quantity
                                      ELSE 0
                                   END
                                  ) AS total_pushout
                          FROM bolinf.xx_old_plan_child_gtt
                         WHERE organization_id =
                                               NVL (p_org_id, organization_id)
                           AND TRUNC (new_wip_start_date)
                                  BETWEEN TRUNC (p_old_start_date)
                                      AND TRUNC (p_date)
                      GROUP BY child_id, organization_id, wip_issued_qty) o
                     LEFT JOIN
                     (SELECT   child_id, organization_id, wip_issued_qty,
                               SUM
                                  (CASE
                                      WHEN supply_type IN
                                              ('Onhand', 'Intransit receipt')
                                         THEN allocated_quantity
                                      ELSE 0
                                   END
                                  ) AS onhand,
                               SUM
                                  (CASE
                                      WHEN supply_type IN
                                             ('Purchase order', 'Onhand',
                                              'Intransit shipment',
                                              'Intransit receipt',
                                              'PO in receiving')
                                         THEN allocated_quantity
                                      ELSE 0
                                   END
                                  ) AS total_pushout
                          FROM bolinf.xx_new_plan_child_gtt
                         WHERE organization_id =
                                               NVL (p_org_id, organization_id)
                           AND TRUNC (new_wip_start_date)
                                  BETWEEN TRUNC (p_new_start_date)
                                      AND TRUNC (p_date)
                      GROUP BY child_id, organization_id, wip_issued_qty) n
                     ON o.child_id = n.child_id
                   AND o.organization_id = n.organization_id
                     );

   DELETE FROM bolinf.rpt_cancelled_data;

   -- Insert Cancelled Data (child-level only)
   INSERT INTO bolinf.rpt_cancelled_data
               (child_id, organization_id, wip_issued_qty, onhand_cancelled,
                poir_cancelled)
      SELECT child_id, organization_id, wip_issued_qty,
             CASE
                WHEN wip_issued_qty > 0
                   THEN (onhand_cancelled - wip_issued_qty
                        )
                ELSE onhand_cancelled
             END AS final_onhand_cancelled,
             CASE
                WHEN wip_issued_qty > 0
                   THEN (total_cancelled - wip_issued_qty
                        )
                ELSE total_cancelled
             END AS final_total_cancelled
        FROM (SELECT o.child_id, o.organization_id, o.wip_issued_qty,
                     NVL (o.onhand, 0)
                     - NVL (n.onhand, 0) AS onhand_cancelled,
                       NVL (o.total_cancelled, 0)
                     - NVL (n.total_cancelled, 0) AS total_cancelled
                FROM (SELECT   child_id, organization_id, wip_issued_qty,
                               SUM
                                  (CASE
                                      WHEN supply_type IN
                                              ('Onhand', 'Intransit receipt')
                                         THEN allocated_quantity
                                      ELSE 0
                                   END
                                  ) AS onhand,
                               SUM
                                  (CASE
                                      WHEN supply_type IN
                                             ('Purchase order', 'Onhand',
                                              'Intransit shipment',
                                              'Intransit receipt',
                                              'PO in receiving')
                                         THEN allocated_quantity
                                      ELSE 0
                                   END
                                  ) AS total_cancelled
                          FROM bolinf.xx_old_plan_child_gtt
                         WHERE organization_id =
                                               NVL (p_org_id, organization_id)
                      GROUP BY child_id, organization_id, wip_issued_qty) o
                     LEFT JOIN
                     (SELECT   child_id, organization_id, wip_issued_qty,
                               SUM
                                  (CASE
                                      WHEN supply_type IN
                                              ('Onhand', 'Intransit receipt')
                                         THEN allocated_quantity
                                      ELSE 0
                                   END
                                  ) AS onhand,
                               SUM
                                  (CASE
                                      WHEN supply_type IN
                                             ('Purchase order', 'Onhand',
                                              'Intransit shipment',
                                              'Intransit receipt',
                                              'PO in receiving')
                                         THEN allocated_quantity
                                      ELSE 0
                                   END
                                  ) AS total_cancelled
                          FROM bolinf.xx_new_plan_child_gtt
                         WHERE organization_id =
                                               NVL (p_org_id, organization_id)
                      GROUP BY child_id, organization_id, wip_issued_qty) n
                     ON o.child_id = n.child_id
                   AND o.organization_id = n.organization_id
                     );

   COMMIT;
EXCEPTION
   WHEN OTHERS
   THEN
      ROLLBACK;
      raise_application_error (-20003,
                                  'Error in insert_pushout_cancelled_data: '
                               || SQLERRM
                              );
END;
/