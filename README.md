📦 Inventory Pushout and Cancelled Report
📌 Project Overview

The Inventory Pushout and Cancelled Report is a business-driven reporting solution designed to determine the value of Raw Material (RM) inventory impacted due to demand pushouts greater than 8 weeks and cancelled demands.

This report provides critical visibility into inventory exposure caused by demand changes and helps supply chain, planning, and inventory teams take proactive decisions to minimize excess and obsolete stock.

🎯 Business Objective

The primary objectives of this report are:

Identify Raw Material inventory affected by demand pushouts exceeding 8 weeks

Identify Raw Material inventory impacted due to cancelled demands

Quantify the financial value of affected inventory

Support inventory risk assessment and planning optimization

Enable data-driven decision-making for supply chain stakeholders

🧠 Problem Statement

Frequent changes in customer demand—such as significant schedule pushouts or order cancellations—can result in:

Excess Raw Material inventory

Increased inventory carrying costs

Risk of obsolete or slow-moving stock

This report addresses the above challenges by systematically identifying affected inventory and calculating its value based on defined business rules.

📊 Report Scope

The report analyzes:

Demand records with revised dates pushed out more than 8 weeks from the original demand date

Fully cancelled demand lines

Associated Raw Material inventory linked to impacted demands

Inventory value based on applicable costing logic

⚙️ Report Logic (High-Level)

Extract demand data from the planning system.

Identify demand lines where:

The revised demand date exceeds the original demand date by more than 8 weeks, OR

The demand is cancelled.

Map impacted demands to corresponding Raw Material items.

Calculate impacted RM quantity.

Derive inventory value using standard costing rules.

Present results in the defined reporting format.

🛠️ Technologies Used

Oracle ERP / Oracle EBS

SQL

PL/SQL

Inventory & Supply Chain data models

🚀 Key Benefits

Improves visibility of inventory risks caused by demand volatility

Helps reduce excess and obsolete inventory

Supports proactive supply chain planning

Saves manual analysis time through automated reporting

📈 Business Impact

Enabled early identification of high-risk RM inventory

Supported cost control initiatives

Improved coordination between planning and inventory teams

Reduced dependency on manual data analysis


👩‍💻 Author

Mitali Lohar
PL/SQL & Oracle ERP Developer
Experience in Oracle EBS, SCM, and backend development
