CREATE OR REPLACE PROCEDURE APPS.xx_ins_pushout_cancelled_data1 (
    p_org_id              IN NUMBER DEFAULT NULL,
    p_old_start_date      IN DATE,
    p_new_start_date      IN DATE,
    p_old_week_end_date   IN DATE,
    p_new_week_end_date   IN DATE
) IS
BEGIN
  DELETE FROM bolinf.rpt_pushout_data;

  -- Insert Pushout Data (child-level only)
  INSERT INTO bolinf.rpt_pushout_data (
    child_id,
    organization_id,
    pushout_onhand,
    pushout_po,
    pushout_poir
  )
  SELECT 
    o.child_id,
    o.organization_id,
    NVL(GREATEST(NVL(o.onhand, 0) - NVL(n.onhand, 0), 0), 0) AS pushout_onhand,
    NVL(GREATEST(NVL(o.po, 0) - NVL(n.po, 0), 0), 0) AS pushout_po,
    NVL(GREATEST(NVL(o.poir, 0) - NVL(n.poir, 0), 0), 0) AS pushout_poir
  FROM (
    SELECT 
      child_id,
      organization_id,
      SUM(CASE WHEN supply_type = 'Onhand' THEN allocated_quantity ELSE 0 END) AS onhand,
      SUM(CASE WHEN supply_type = 'Purchase order' THEN allocated_quantity ELSE 0 END) AS po,
      SUM(CASE WHEN supply_type = 'PO in receiving' THEN allocated_quantity ELSE 0 END) AS poir
    FROM bolinf.xx_old_plan_child_gtt
    WHERE organization_id = NVL(p_org_id, organization_id)
      AND TRUNC(new_wip_start_date) BETWEEN TRUNC(p_old_start_date) AND TRUNC(p_old_week_end_date)
    GROUP BY child_id, organization_id
  ) o
  LEFT JOIN (
    SELECT 
      child_id,
      organization_id,
      SUM(CASE WHEN supply_type = 'Onhand' THEN allocated_quantity ELSE 0 END) AS onhand,
      SUM(CASE WHEN supply_type = 'Purchase order' THEN allocated_quantity ELSE 0 END) AS po,
      SUM(CASE WHEN supply_type = 'PO in receiving' THEN allocated_quantity ELSE 0 END) AS poir
    FROM bolinf.xx_new_plan_child_gtt
    WHERE organization_id = NVL(p_org_id, organization_id)
      AND TRUNC(new_wip_start_date) BETWEEN TRUNC(p_new_start_date) AND TRUNC(p_new_week_end_date)
    GROUP BY child_id, organization_id
  ) n ON o.child_id = n.child_id
     AND o.organization_id = n.organization_id;


  DELETE FROM bolinf.rpt_cancelled_data;

  -- Insert Cancelled Data (child-level only)
  INSERT INTO bolinf.rpt_cancelled_data (
    child_id,
    organization_id,
    onhand_cancelled,
    po_cancelled,
    poir_cancelled
  )
  SELECT 
    o.child_id,
    o.organization_id,
    NVL(GREATEST(NVL(o.onhand, 0) - NVL(n.onhand, 0), 0), 0) AS onhand_cancelled,
    NVL(GREATEST(NVL(o.po, 0) - NVL(n.po, 0), 0), 0) AS po_cancelled,
    NVL(GREATEST(NVL(o.poir, 0) - NVL(n.poir, 0), 0), 0) AS poir_cancelled
  FROM (
    SELECT 
      child_id,
      organization_id,
      SUM(CASE WHEN supply_type = 'Onhand' THEN allocated_quantity ELSE 0 END) AS onhand,
      SUM(CASE WHEN supply_type = 'Purchase order' THEN allocated_quantity ELSE 0 END) AS po,
      SUM(CASE WHEN supply_type = 'PO in receiving' THEN allocated_quantity ELSE 0 END) AS poir
    FROM bolinf.xx_old_plan_child_gtt
    WHERE organization_id = NVL(p_org_id, organization_id)
    GROUP BY child_id, organization_id
  ) o
  LEFT JOIN (
    SELECT 
      child_id,
      organization_id,
      SUM(CASE WHEN supply_type = 'Onhand' THEN allocated_quantity ELSE 0 END) AS onhand,
      SUM(CASE WHEN supply_type = 'Purchase order' THEN allocated_quantity ELSE 0 END) AS po,
      SUM(CASE WHEN supply_type = 'PO in receiving' THEN allocated_quantity ELSE 0 END) AS poir
    FROM bolinf.xx_new_plan_child_gtt
    WHERE organization_id = NVL(p_org_id, organization_id)
    GROUP BY child_id, organization_id
  ) n ON o.child_id = n.child_id
     AND o.organization_id = n.organization_id;

  COMMIT;

EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
    RAISE_APPLICATION_ERROR( -20003, 'Error in insert_pushout_cancelled_data: ' || SQLERRM);
END;
/


select * from bolinf.rpt_pushout_data where child_id = 2400