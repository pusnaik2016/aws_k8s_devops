#!/usr/bin/env python3
"""Generate updated resume PDF with requested changes."""

from fpdf import FPDF

# ─── Constants ───
MARGIN_LEFT = 12
MARGIN_RIGHT = 12
PAGE_W = 210
CONTENT_W = PAGE_W - MARGIN_LEFT - MARGIN_RIGHT
COL1_W = 50  # Left column width (competencies)
COL2_W = CONTENT_W - COL1_W - 4  # Right column width

# Colors
DARK_BLUE = (20, 50, 90)
MID_BLUE = (40, 80, 140)
ACCENT_BLUE = (30, 60, 110)
LIGHT_BLUE_BG = (230, 240, 250)
DARK_TEXT = (30, 30, 30)
GRAY = (80, 80, 80)
WHITE = (255, 255, 255)


class ResumePDF(FPDF):
    def __init__(self):
        super().__init__('P', 'mm', 'A4')
        self.set_auto_page_break(True, margin=12)
        # Add standard fonts only - no custom fonts needed
        
    def section_heading(self, text, y_offset=2):
        self.ln(y_offset)
        self.set_fill_color(*ACCENT_BLUE)
        self.set_text_color(*WHITE)
        self.set_font('Helvetica', 'B', 10)
        self.cell(CONTENT_W, 6.5, f'  {text}', fill=True, new_x="LMARGIN", new_y="NEXT")
        self.set_text_color(*DARK_TEXT)
        self.ln(2)

    def sub_heading(self, text, y_offset=1):
        self.ln(y_offset)
        self.set_font('Helvetica', 'B', 9.5)
        self.set_text_color(*MID_BLUE)
        self.cell(0, 5, text, new_x="LMARGIN", new_y="NEXT")
        self.set_text_color(*DARK_TEXT)
        self.ln(0.5)

    def bullet(self, bold_part, text, indent=2):
        self.set_x(MARGIN_LEFT + indent)
        self.set_font('Helvetica', '', 8)
        bullet_char = "- "
        if bold_part:
            self.set_font('Helvetica', 'B', 8)
            self.write(4, f"{bullet_char}{bold_part}: ")
            self.set_font('Helvetica', '', 8)
            self.multi_cell(CONTENT_W - indent - 2, 4, text, new_x="LMARGIN", new_y="NEXT")
        else:
            self.multi_cell(CONTENT_W - indent - 2, 4, f"{bullet_char}{text}", new_x="LMARGIN", new_y="NEXT")
        self.ln(0.8)

    def small_bullet(self, text, indent=4):
        self.set_x(MARGIN_LEFT + indent)
        self.set_font('Helvetica', '', 7.5)
        self.multi_cell(CONTENT_W - indent - 2, 3.8, f"* {text}", new_x="LMARGIN", new_y="NEXT")
        self.ln(0.3)

    def draw_header_line(self):
        self.set_draw_color(*ACCENT_BLUE)
        self.set_line_width(0.5)
        self.line(MARGIN_LEFT, self.get_y(), PAGE_W - MARGIN_RIGHT, self.get_y())
        self.ln(2)


def build_page1(pdf):
    pdf.add_page()
    pdf.set_margins(MARGIN_LEFT, 10, MARGIN_RIGHT)

    # ─── Name & Contact Header ───
    pdf.set_font('Helvetica', 'B', 22)
    pdf.set_text_color(*DARK_BLUE)
    pdf.cell(0, 10, 'PUSHPARAJ NAIK', align='C', new_x="LMARGIN", new_y="NEXT")

    pdf.set_font('Helvetica', '', 8.5)
    pdf.set_text_color(*GRAY)
    pdf.cell(0, 4.5, '+91-9972088444  |  pushparaj.naik@gmail.com', align='C', new_x="LMARGIN", new_y="NEXT")

    pdf.set_font('Helvetica', 'B', 9)
    pdf.set_text_color(*MID_BLUE)
    pdf.cell(0, 5.5, 'Lead Cloud Architect | AWS | DevOps | Terraform | CI/CD | IoT & Edge Computing', align='C', new_x="LMARGIN", new_y="NEXT")
    pdf.ln(2)
    pdf.draw_header_line()

    # ─── Two-column layout ───
    col1_x = MARGIN_LEFT
    col2_x = MARGIN_LEFT + COL1_W + 4
    top_y = pdf.get_y()

    # ──── LEFT COLUMN ────
    pdf.set_xy(col1_x, top_y)
    pdf.set_fill_color(*LIGHT_BLUE_BG)
    pdf.set_font('Helvetica', 'B', 9)
    pdf.set_text_color(*ACCENT_BLUE)
    pdf.cell(COL1_W, 5.5, 'CORE COMPETENCIES', new_x="LMARGIN", new_y="NEXT")
    pdf.set_x(col1_x)
    pdf.ln(2)

    competencies = [
        "Cloud Architecture & Enterprise\nSolution Design",
        "AWS Cloud Platform Engineering",
        "Infrastructure as Code (Terraform\n& Automation)",
        "DevOps & CI/CD Pipeline\nEngineering",
        "Containerization & Microservices\nDeployment",
        "Cloud Security & Governance",
        "Network Architecture & Hybrid\nCloud Integration",
        "Edge Computing & IoT Architecture",
        "Agile Delivery & Technical\nLeadership",
        "Configuration Management &\nSource Control (GitOps)",
    ]
    pdf.set_font('Helvetica', '', 7.5)
    pdf.set_text_color(*DARK_TEXT)
    for comp in competencies:
        pdf.set_x(col1_x)
        pdf.multi_cell(COL1_W, 3.8, f"* {comp}", new_x="LMARGIN", new_y="NEXT")
        pdf.ln(1)

    # Education
    pdf.ln(2)
    pdf.set_x(col1_x)
    pdf.set_font('Helvetica', 'B', 9)
    pdf.set_text_color(*ACCENT_BLUE)
    pdf.cell(COL1_W, 5.5, 'EDUCATION', new_x="LMARGIN", new_y="NEXT")
    pdf.set_x(col1_x)
    pdf.ln(1.5)
    pdf.set_font('Helvetica', '', 7.5)
    pdf.set_text_color(*DARK_TEXT)
    pdf.set_x(col1_x)
    pdf.multi_cell(COL1_W, 3.8, "Bachelor of Engineering\n(Computer Science & Engineering)\nBMS College of Engineering,\nVTU, Karnataka", new_x="LMARGIN", new_y="NEXT")

    # Awards
    pdf.ln(3)
    pdf.set_x(col1_x)
    pdf.set_font('Helvetica', 'B', 9)
    pdf.set_text_color(*ACCENT_BLUE)
    pdf.cell(COL1_W, 5.5, 'AWARDS', new_x="LMARGIN", new_y="NEXT")
    pdf.set_x(col1_x)
    pdf.ln(1.5)
    pdf.set_font('Helvetica', '', 7)
    pdf.set_text_color(*DARK_TEXT)
    pdf.set_x(col1_x)
    pdf.multi_cell(COL1_W, 3.5, "* Feather in My Cap Award - Wipro (2014): Recognized for delivering end-to-end test automation for a Cisco ASA security project.", new_x="LMARGIN", new_y="NEXT")
    pdf.ln(1)
    pdf.set_x(col1_x)
    pdf.multi_cell(COL1_W, 3.5, "* Team Mesh Award - Wipro (2018): Led DevOps automation implementation for Python-based testing on Cisco HyperFlex storage platforms.", new_x="LMARGIN", new_y="NEXT")

    # ──── RIGHT COLUMN ────
    pdf.set_xy(col2_x, top_y)

    # Job Objective
    pdf.set_font('Helvetica', 'B', 9)
    pdf.set_text_color(*ACCENT_BLUE)
    pdf.cell(COL2_W, 5.5, 'JOB OBJECTIVE', new_x="LMARGIN", new_y="NEXT")
    pdf.set_xy(col2_x, pdf.get_y() + 1)
    pdf.set_font('Helvetica', '', 8)
    pdf.set_text_color(*DARK_TEXT)
    pdf.multi_cell(COL2_W, 4, "Senior Cloud Architect / Lead Cloud Architect with 22+ years of experience in designing and delivering enterprise-scale AWS cloud platforms, leading cloud transformation initiatives, and architecting secure, highly available, and scalable solutions using DevOps, Terraform, CI/CD automation & containerization to drive modernization, operational excellence, and business resilience in complex global environments.", new_x="LMARGIN", new_y="NEXT")

    # Profile Summary
    pdf.ln(2)
    pdf.set_x(col2_x)
    pdf.set_font('Helvetica', 'B', 9)
    pdf.set_text_color(*ACCENT_BLUE)
    pdf.cell(COL2_W, 5.5, 'PROFILE SUMMARY', new_x="LMARGIN", new_y="NEXT")
    pdf.set_x(col2_x)
    pdf.ln(1)

    summaries = [
        ("Enterprise Cloud Architecture Leadership", "Seasoned Cloud Architect with 22+ years of experience designing and delivering large-scale AWS cloud platforms ensuring high availability, scalability, security, and enterprise-grade resilience."),
        ("DevOps & CI/CD Transformation Expert", "Proven expertise in building end-to-end CI/CD pipelines and DevOps ecosystems using Jenkins, Azure DevOps, Terraform, and automation frameworks to accelerate delivery and improve deployment efficiency."),
        ("Infrastructure Automation & Modernization", "Strong experience in Infrastructure as Code (Terraform, CloudFormation) and containerization (Docker, ECS, Kubernetes) enabling seamless cloud migration and modernization of legacy systems."),
        ("Security & Monitoring Focus", "Expertise in implementing robust monitoring, logging, and alerting using CloudWatch and Datadog while enforcing enterprise security governance through IAM, WAF, and GuardDuty."),
    ]
    for bold, text in summaries:
        pdf.set_x(col2_x)
        pdf.set_font('Helvetica', 'B', 7.5)
        pdf.write(3.8, f"* {bold}: ")
        pdf.set_font('Helvetica', '', 7.5)
        pdf.multi_cell(COL2_W, 3.8, text, new_x="LMARGIN", new_y="NEXT")
        pdf.ln(1)

    # ─── WORK EXPERIENCE (full width, below columns) ───
    pdf.ln(3)
    pdf.set_x(MARGIN_LEFT)
    pdf.section_heading('WORK EXPERIENCE', 1)

    pdf.set_font('Helvetica', 'B', 9.5)
    pdf.set_text_color(*MID_BLUE)
    pdf.cell(0, 5, 'ITC Infotech, Bengaluru | AWS Cloud Architect | Feb 2025 - Present', new_x="LMARGIN", new_y="NEXT")
    pdf.set_font('Helvetica', 'I', 8)
    pdf.set_text_color(*GRAY)
    pdf.cell(0, 4, 'Project: Advantest Cloud Migration (GLP, FNO, AOL)', new_x="LMARGIN", new_y="NEXT")
    pdf.set_text_color(*DARK_TEXT)
    pdf.ln(1)

    bullets_itc = [
        ("Cloud Architecture Design", "Designed enterprise AWS cloud architecture ensuring high availability, scalability, security, and alignment with business and AWS best practices for mission-critical applications."),
        ("Network & VPC Engineering", "Built secure multi-tier VPC architecture with public, private, application & database subnets ensuring network isolation & controlled access."),
        ("Containerization & Workload Modernization", "Led application containerization strategy using Amazon ECS and AWS Batch to enable scalable, resilient & efficient workload deployment."),
        ("Data Migration & Hybrid Connectivity", "Designed multi-AZ RDS (MS-SQL) architecture and executed migration planning using AWS DMS along with secure Site-to-Site VPN and Route 53 Resolver integration."),
        ("Infrastructure & CI/CD Automation", "Developed Infrastructure as Code using Terraform and implemented CI/CD pipelines with AWS CodePipeline, CodeBuild, and GitHub Actions for automated and consistent deployments."),
        ("DevOps & DevSecOps Practices", "Applied DORA-aligned DevOps practices and integrated security and quality tools such as Trivy, SonarCloud, and JaCoCo into CI/CD pipelines to ensure secure, reliable, and high-quality releases."),
        ("Edge Computing & IoT Innovation", "Designed AWS IoT Core and Greengrass-based edge architecture enabling offline processing, telemetry buffering, and secure distributed license processing across customer environments."),
        ("Security & Governance Automation", "Implemented enterprise cloud security controls using IAM, WAF, GuardDuty, and Security Hub with automated policy enforcement and continuous compliance validation."),
        ("Observability & Resilience Engineering", "Established centralized monitoring and alerting using CloudWatch dashboards ensuring proactive incident detection, faster RCA, and improved system reliability across environments."),
    ]
    for bold, text in bullets_itc:
        pdf.bullet(bold, text)


def build_page2(pdf):
    pdf.add_page()
    pdf.set_margins(MARGIN_LEFT, 10, MARGIN_RIGHT)

    # ─── Wipro Header ───
    pdf.set_font('Helvetica', 'B', 10)
    pdf.set_text_color(*DARK_BLUE)
    pdf.cell(0, 6, 'Wipro Limited, Bengaluru | Growth Path | 2013 - 2025', new_x="LMARGIN", new_y="NEXT")
    pdf.draw_header_line()

    # ─── HPE K-GPT ───
    pdf.sub_heading('AWS Cloud Architect | May 2021 - Feb 2025')
    pdf.set_font('Helvetica', 'I', 8)
    pdf.set_text_color(*GRAY)
    pdf.cell(0, 4, 'Project: HPE - K-GPT (AI Document Search Platform)', new_x="LMARGIN", new_y="NEXT")
    pdf.set_text_color(*DARK_TEXT)
    pdf.ln(1)

    bullets_hpe = [
        ("Cloud Architecture Design", "Designed scalable AWS cloud infrastructure for enterprise AI-based search systems ensuring high availability, security, and performance at scale."),
        ("Infrastructure Automation (Terraform)", "Built and managed cloud environments using Terraform enabling consistent, reusable, and automated infrastructure provisioning across multiple environments."),
        ("Edge & CI/CD Engineering", "Developed AWS Greengrass edge components (Lambda + containers) and integrated CI/CD pipelines using Azure DevOps for seamless deployment automation."),
        ("Logging and Monitoring", "Utilized Amazon CloudWatch, AWS CloudTrail, and Splunk to implement centralized logging, proactive monitoring, and operational insights for production environments."),
        ("Private EKS & API Ingress Architecture", "Architected a private Amazon EKS cluster running behind Network Load Balancers and VPC endpoints (PrivateLink), with user requests routed via Amazon Route 53 and Amazon API Gateway for secure, controlled, and scalable workload management."),
        ("Cloud Security, Governance & Compliance", "Designed and enforced secure cloud governance using IAM policies, network segmentation, encryption standards, and least-privilege access controls across distributed AWS environments, aligned with compliance requirements such as HIPAA, SOX, PCI-DSS, and GDPR."),
    ]
    for bold, text in bullets_hpe:
        pdf.bullet(bold, text)

    # ─── Nokia NetAct ───
    pdf.ln(1)
    pdf.sub_heading('AWS Cloud Architect | May 2019 - Apr 2021')
    pdf.set_font('Helvetica', 'I', 8)
    pdf.set_text_color(*GRAY)
    pdf.cell(0, 4, 'Project: Nokia NetAct (Telecom Network Management System)', new_x="LMARGIN", new_y="NEXT")
    pdf.set_text_color(*DARK_TEXT)
    pdf.ln(1)

    nokia_bullets = [
        "Migrated legacy systems to AWS cloud using Terraform and Ansible",
        "Designed and deployed EC2, Lambda, S3, RDS, ELB, Auto Scaling architectures",
        "Built CI/CD pipelines integrating Git, Jenkins, Maven, Docker",
        "Automated infrastructure provisioning using Terraform scripts",
        "Implemented Docker-based deployment workflows",
        "Enabled monitoring and incident management for production systems",
        "Managed Agile teams and supported release cycles",
    ]
    for b in nokia_bullets:
        pdf.small_bullet(b)

    # ─── Cisco DOCSIS ───
    pdf.ln(1)
    pdf.sub_heading('Solution Architect | May 2013 - Apr 2019')
    pdf.set_font('Helvetica', 'I', 8)
    pdf.set_text_color(*GRAY)
    pdf.cell(0, 4, 'Project: Cisco DOCSIS Integration', new_x="LMARGIN", new_y="NEXT")
    pdf.set_text_color(*DARK_TEXT)
    pdf.ln(1)

    cisco_bullets = [
        "Designed automated deployment frameworks using Ansible and AWS CloudFormation",
        "Built CI/CD pipelines using Jenkins and Git",
        "Developed Python automation scripts for AWS API operations",
        "Implemented Master-Slave Jenkins architecture for scalability",
        "Supported performance, scalability, and HA testing",
        "Worked closely with Dev and QA teams for release readiness",
    ]
    for b in cisco_bullets:
        pdf.small_bullet(b)

    # ─── Prior Roles (compact) ───
    pdf.ln(2)
    pdf.section_heading('PRIOR EXPERIENCE', 1)

    prior_roles = [
        ("Test Specialist | IBM India Pvt. Ltd (Ericsson Client)", "Aug 2010 - Mar 2013", "Managed UAT, staging, and production builds; provided 24/7 operational support; conducted system testing and validation."),
        ("Senior Test Engineer | Capgemini (Aricent Group)", "Feb 2006 - Jul 2010", "Worked on VoIP/SIP telecom deployments; performed onsite installation and customer support (France, Germany); managed system integration."),
        ("Analyst | Verizon Data Services", "Sep 2005 - Jan 2006", "Test framework development using TCL/Expect; basic call testing and validation."),
        ("Project Engineer | Wipro Technologies", "Apr 2004 - Sep 2005", "Test automation and SIP endpoint testing; lab administration activities."),
    ]
    for title, dates, desc in prior_roles:
        pdf.set_font('Helvetica', 'B', 8)
        pdf.set_text_color(*MID_BLUE)
        pdf.cell(0, 4.5, f"{title} | {dates}", new_x="LMARGIN", new_y="NEXT")
        pdf.set_font('Helvetica', '', 7.5)
        pdf.set_text_color(*DARK_TEXT)
        pdf.multi_cell(CONTENT_W, 3.8, desc, new_x="LMARGIN", new_y="NEXT")
        pdf.ln(1.5)

    # ─── Certifications ───
    pdf.ln(1)
    pdf.section_heading('CERTIFICATIONS', 1)
    certs = [
        "AWS Certified Cloud Practitioner (2023)",
        "AWS Certified Solutions Architect - Associate (2023)",
        "Google Cloud Professional Cloud Architect (2023)",
    ]
    for c in certs:
        pdf.small_bullet(c, indent=2)


def build_page3(pdf):
    pdf.add_page()
    pdf.set_margins(MARGIN_LEFT, 10, MARGIN_RIGHT)

    pdf.section_heading('TECHNICAL SKILLS', 1)

    skills = [
        ("Cloud Platforms", "AWS (EC2, EKS, ECS, Lambda, S3, DynamoDB, Aurora RDS, MSSQL RDS, VPC, Route 53, CloudFront, IAM, WAF, CloudWatch, SNS, SQS, EventBridge, Glue, DMS, MGN)"),
        ("DevOps Tools", "Jenkins, Azure DevOps, AWS CodePipeline, AWS CodeBuild, GitHub Actions, ArgoCD"),
        ("IaC & Automation", "Terraform, AWS CloudFormation"),
        ("Containers", "Docker, Kubernetes, Amazon ECS, Amazon EKS"),
        ("Programming/Scripting", "Python, Shell Scripting"),
        ("Logging and Monitoring", "AWS CloudWatch, Splunk, AWS CloudTrail"),
        ("Networking", "VPC design, VPN, load balancers, DNS architecture"),
        ("Security", "IAM, AWS Security Hub, Amazon GuardDuty, AWS WAF, AWS KMS, Secret Manager, ACM"),
        ("SCM Tools", "Git, Bitbucket, GitHub"),
    ]
    for category, items in skills:
        pdf.set_font('Helvetica', 'B', 8.5)
        pdf.set_text_color(*ACCENT_BLUE)
        pdf.cell(42, 5, f"{category}:", new_x="END")
        pdf.set_font('Helvetica', '', 8)
        pdf.set_text_color(*DARK_TEXT)
        pdf.multi_cell(CONTENT_W - 42, 4.5, items, new_x="LMARGIN", new_y="NEXT")
        pdf.ln(2)

    # ─── Personal Details ───
    pdf.ln(4)
    pdf.section_heading('PERSONAL DETAILS', 1)

    details = [
        ("Languages Known", "English, Hindi, Kannada"),
        ("Address", "Bangalore, India"),
    ]
    for label, value in details:
        pdf.set_font('Helvetica', 'B', 8.5)
        pdf.cell(35, 5, f"{label}:", new_x="END")
        pdf.set_font('Helvetica', '', 8.5)
        pdf.cell(0, 5, f" {value}", new_x="LMARGIN", new_y="NEXT")
        pdf.ln(1)


def main():
    pdf = ResumePDF()
    build_page1(pdf)
    build_page2(pdf)
    build_page3(pdf)
    
    output_path = "/Users/pushparajnaik/Desktop/TerraformCode/AWS_DevOps_K8s_clean/Documents/Resume_Naukri1_Updated.pdf"
    pdf.output(output_path)
    print(f"Resume generated: {output_path}")
    print(f"Pages: {pdf.pages_count}")


if __name__ == "__main__":
    main()
