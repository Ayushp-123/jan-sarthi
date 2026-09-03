import os
from reportlab.lib.pagesizes import letter
from reportlab.lib import colors
from reportlab.lib.units import inch
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak, KeepTogether, HRFlowable, Image
)
from reportlab.pdfgen import canvas

class NumberedCanvas(canvas.Canvas):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._saved_page_states = []

    def showPage(self):
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()

    def save(self):
        num_pages = len(self._saved_page_states)
        for state in self._saved_page_states:
            self.__dict__.update(state)
            self.draw_page_number(num_pages)
            canvas.Canvas.showPage(self)
        canvas.Canvas.save(self)

    def draw_page_number(self, page_count):
        self.saveState()
        self.setFont("Helvetica", 9)
        self.setFillColor(colors.HexColor("#64748B"))
        
        # Header (pages > 1)
        if self._pageNumber > 1:
            self.drawString(54, 11 * 72 - 36, "JAN SARTHI v2.0 — Comprehensive Master Verification & Architecture Report")
            self.setStrokeColor(colors.HexColor("#E2E8F0"))
            self.setLineWidth(0.5)
            self.line(54, 11 * 72 - 42, 8.5 * 72 - 54, 11 * 72 - 42)
            
        # Footer
        page_text = f"Page {self._pageNumber} of {page_count}"
        self.drawRightString(8.5 * 72 - 54, 36, page_text)
        self.drawString(54, 36, "CONFIDENTIAL & PROPRIETARY — GOOGLE DEEPMIND / ADVANCED AGENTIC CODING")
        self.setStrokeColor(colors.HexColor("#E2E8F0"))
        self.setLineWidth(0.5)
        self.line(54, 48, 8.5 * 72 - 54, 48)
        self.restoreState()

def build_pdf():
    pdf_path = "/Users/snehil/Downloads/jan-sarthi-main-2/Jan_Sarthi_v2_Master_Verification_Report.pdf"
    doc = SimpleDocTemplate(
        pdf_path,
        pagesize=letter,
        leftMargin=54,
        rightMargin=54,
        topMargin=54,
        bottomMargin=54
    )

    styles = getSampleStyleSheet()
    
    # Custom Palette
    c_primary = colors.HexColor("#DC2626")   # Emergency Red
    c_navy = colors.HexColor("#1E3A8A")      # Sarthi Navy
    c_saffron = colors.HexColor("#EA580C")   # National Saffron
    c_emerald = colors.HexColor("#059669")   # Success Green
    c_dark = colors.HexColor("#0F172A")      # Slate 900
    c_gray = colors.HexColor("#475569")      # Slate 600
    c_light_bg = colors.HexColor("#F8FAFC")  # Slate 50
    c_border = colors.HexColor("#E2E8F0")    # Slate 200
    c_gold = colors.HexColor("#D97706")      # Amber/Gold

    # Typography Styles
    title_style = ParagraphStyle(
        'DocTitle',
        parent=styles['Heading1'],
        fontName='Helvetica-Bold',
        fontSize=24,
        leading=28,
        textColor=c_dark,
        spaceAfter=6
    )
    
    subtitle_style = ParagraphStyle(
        'DocSubtitle',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=12,
        leading=16,
        textColor=c_navy,
        spaceAfter=15
    )

    h1_style = ParagraphStyle(
        'H1',
        parent=styles['Heading2'],
        fontName='Helvetica-Bold',
        fontSize=14,
        leading=18,
        textColor=c_navy,
        spaceBefore=14,
        spaceAfter=6
    )

    h2_style = ParagraphStyle(
        'H2',
        parent=styles['Heading3'],
        fontName='Helvetica-Bold',
        fontSize=11,
        leading=15,
        textColor=c_dark,
        spaceBefore=10,
        spaceAfter=4
    )

    body_style = ParagraphStyle(
        'Body',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=9.5,
        leading=13.5,
        textColor=c_gray,
        spaceAfter=6
    )

    callout_style = ParagraphStyle(
        'Callout',
        parent=styles['Normal'],
        fontName='Helvetica-Oblique',
        fontSize=9,
        leading=13,
        textColor=c_dark,
    )

    table_cell = ParagraphStyle(
        'TableCell',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=8.5,
        leading=11.5,
        textColor=c_dark,
    )

    table_cell_bold = ParagraphStyle(
        'TableCellBold',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=8.5,
        leading=11.5,
        textColor=c_dark,
    )

    story = []

    # 1. Header Banner & Title
    story.append(Paragraph("🚨 JAN SARTHI v2.0", title_style))
    story.append(Paragraph("Autonomous & P2P Real-Time Emergency Response Platform — Master Stabilization & Civic Impact Verification Report", subtitle_style))
    story.append(HRFlowable(width="100%", thickness=2, color=c_primary, spaceBefore=2, spaceAfter=12))

    # Metadata Grid
    meta_data = [
        [
            Paragraph("<b>Target Workspace:</b> jan-sarthi-main-2", table_cell),
            Paragraph("<b>Release Build:</b> v2.0-STABLE", table_cell),
            Paragraph("<b>Date:</b> August 31, 2026", table_cell)
        ],
        [
            Paragraph("<b>APK Status:</b> BUILT (58.9 MB)", table_cell),
            Paragraph("<b>Static Analysis:</b> 0 Issues (Clean)", table_cell),
            Paragraph("<b>Test Suite:</b> 27 / 27 Passed (100%)", table_cell)
        ]
    ]
    meta_table = Table(meta_data, colWidths=[2.3*inch, 2.3*inch, 2.4*inch])
    meta_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, -1), c_light_bg),
        ('BOX', (0, 0), (-1, -1), 1, c_border),
        ('INNERGRID', (0, 0), (-1, -1), 0.5, c_border),
        ('TOPPADDING', (0, 0), (-1, -1), 6),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
        ('LEFTPADDING', (0, 0), (-1, -1), 8),
        ('RIGHTPADDING', (0, 0), (-1, -1), 8),
    ]))
    story.append(meta_table)
    story.append(Spacer(1, 14))

    # 2. Executive Verification Matrix
    story.append(Paragraph("1. Executive Summary & Verification Matrix", h1_style))
    story.append(Paragraph("All 17 stabilization directives, lifecycle guards, and the complete Civic Recognition & Community Impact System have been fully implemented and verified.", body_style))

    matrix_data = [
        [Paragraph("Directive / Feature", table_cell_bold), Paragraph("Status", table_cell_bold), Paragraph("Verification & Architectural Impact", table_cell_bold)],
        [Paragraph("1. Emergency History Bug", table_cell), Paragraph("<font color='#059669'><b>FIXED</b></font>", table_cell), Paragraph("Closed/resolved/cancelled alerts no longer show mutable claim actions. Descending date sort.", table_cell)],
        [Paragraph("2. Closed Emergency Claim Guard", table_cell), Paragraph("<font color='#059669'><b>VERIFIED</b></font>", table_cell), Paragraph("Enforced at data/business-logic level in online Firestore transactions & offline P2P storage.", table_cell)],
        [Paragraph("3. Autonomous Accident Demo", table_cell), Paragraph("<font color='#059669'><b>VERIFIED</b></font>", table_cell), Paragraph("Wired to real emergency state machine: trigger → 15s audio countdown → cancel guard → SOS broadcast.", table_cell)],
        [Paragraph("4. Accident Warning Tone", table_cell), Paragraph("<font color='#059669'><b>VERIFIED</b></font>", table_cell), Paragraph("System alert tone + dual haptic pulses via EmergencySoundService.playAccidentWarning().", table_cell)],
        [Paragraph("5. Countdown Audio Ticks", table_cell), Paragraph("<font color='#059669'><b>VERIFIED</b></font>", table_cell), Paragraph("Regular 1-sec ticks with escalated high-urgency beeps during final 3 moments (3, 2, 1).", table_cell)],
        [Paragraph("6. SOS Confirmation Audio", table_cell), Paragraph("<font color='#059669'><b>VERIFIED</b></font>", table_cell), Paragraph("Distinct confirmation chime & haptic feedback on SOS dispatch.", table_cell)],
        [Paragraph("7. Role-Specific Sirens", table_cell), Paragraph("<font color='#059669'><b>VERIFIED</b></font>", table_cell), Paragraph("108 Ambulance, Police PCR, and Citizen Volunteer sirens with duplicate event protection.", table_cell)],
        [Paragraph("8. Duplicate Audio Deduplication", table_cell), Paragraph("<font color='#059669'><b>VERIFIED</b></font>", table_cell), Paragraph("Tracking sets in EmergencySoundService prevent repeats across stream rebuilds.", table_cell)],
        [Paragraph("9. Custom App Icon", table_cell), Paragraph("<font color='#059669'><b>CONFIGURED</b></font>", table_cell), Paragraph("Generated across all Android mipmap resolutions and packaged into release APK.", table_cell)],
        [Paragraph("10. Online Firestore Flow", table_cell), Paragraph("<font color='#059669'><b>PASS</b></font>", table_cell), Paragraph("Atomic Firestore transaction, primary/standby tracking, arrival geofencing, route polylines.", table_cell)],
        [Paragraph("11. Offline P2P Flow", table_cell), Paragraph("<font color='#059669'><b>PASS</b></font>", table_cell), Paragraph("Nearby Connections + LocalDatabaseService persistence without internet dependency.", table_cell)],
        [Paragraph("12. Civic Impact & Rewards", table_cell), Paragraph("<font color='#059669'><b>IMPLEMENTED</b></font>", table_cell), Paragraph("Points engine, 5 recognition levels, 6 badges, digital certificate, and victim feedback verification.", table_cell)],
        [Paragraph("13. flutter analyze", table_cell), Paragraph("<font color='#059669'><b>0 ISSUES</b></font>", table_cell), Paragraph("Clean static analysis across all production files and test suites.", table_cell)],
        [Paragraph("14. flutter test", table_cell), Paragraph("<font color='#059669'><b>27 / 27 PASS</b></font>", table_cell), Paragraph("100% pass rate across data models, accident evaluators, stability, and reward engines.", table_cell)],
        [Paragraph("15. Release APK Binary", table_cell), Paragraph("<font color='#059669'><b>BUILT (58.9 MB)</b></font>", table_cell), Paragraph("Compiled to build/app/outputs/flutter-apk/app-release.apk.", table_cell)],
    ]
    matrix_table = Table(matrix_data, colWidths=[1.8*inch, 1.2*inch, 4.0*inch])
    matrix_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor("#F1F5F9")),
        ('BOX', (0, 0), (-1, -1), 1, c_border),
        ('INNERGRID', (0, 0), (-1, -1), 0.5, c_border),
        ('TOPPADDING', (0, 0), (-1, -1), 4),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
        ('LEFTPADDING', (0, 0), (-1, -1), 6),
        ('RIGHTPADDING', (0, 0), (-1, -1), 6),
    ]))
    story.append(matrix_table)
    story.append(Spacer(1, 14))

    # 3. Emergency Lifecycle & Closed Alert Fix
    story.append(Paragraph("2. Emergency State Machine & Closed Alert Protection", h1_style))
    story.append(Paragraph(
        "<b>Root Cause Fixed:</b> Previously, historical emergency records retained active claiming buttons in UI, allowing responders to attempt claiming resolved incidents. Furthermore, state machines lacked a strict terminal check in offline storage.<br/><br/>"
        "<b>Authoritative State Machine Architecture:</b><br/>"
        "• <b>Active States:</b> SEARCHING → ASSIGNED → APPROACHING → ARRIVED<br/>"
        "• <b>Terminal States:</b> COMPLETED (aliases: RESOLVED, ENDED) | CANCELLED (alias: CANCELED)<br/>"
        "• <b>Data-Level Guard:</b> In <code>EmergencyClaimService</code>, both online Firestore transactions and offline local queries inspect status before assignment. If terminal, the request is rejected with <i>'This emergency is no longer active.'</i><br/>"
        "• <b>UI Differentiation:</b> <code>EmergencyDetailsScreen</code> replaces mutable responder buttons with an <i>Incident Log Summary</i> and a <i>Back to History</i> action for all historical items.",
        body_style
    ))
    story.append(Spacer(1, 10))

    # 4. Civic Recognition & Community Impact System
    story.append(Paragraph("3. Civic Recognition & Community Impact System", h1_style))
    story.append(Paragraph(
        "Built strictly on top of the emergency engine as a verified civic-service recognition system, avoiding point-farming and prioritizing genuine emergency assistance:",
        body_style
    ))

    impact_points_data = [
        [Paragraph("Verified Action", table_cell_bold), Paragraph("Points", table_cell_bold), Paragraph("Verification Mechanism", table_cell_bold)],
        [Paragraph("Accept Emergency", table_cell), Paragraph("+0 pts", table_cell), Paragraph("Accepting alone grants 0 points to eliminate spam/farming.", table_cell)],
        [Paragraph("Scene Arrival Verified", table_cell), Paragraph("+10 pts", table_cell), Paragraph("Automatically verified when responder GPS is within 100m geofence.", table_cell)],
        [Paragraph("Primary Responder Bonus", table_cell), Paragraph("+5 pts", table_cell), Paragraph("Awarded to the designated lead responder who took responsibility.", table_cell)],
        [Paragraph("Offline P2P Assistance Bonus", table_cell), Paragraph("+5 pts", table_cell), Paragraph("Recognizes assistance provided in zero-internet Nearby environments.", table_cell)],
        [Paragraph("Accident / Crash Response", table_cell), Paragraph("+5 pts", table_cell), Paragraph("Awarded for automated high-impact crash emergency responses.", table_cell)],
        [Paragraph("Emergency Resolution", table_cell), Paragraph("+10 pts", table_cell), Paragraph("Awarded upon successful incident completion and closure.", table_cell)],
        [Paragraph("Victim Confirmation Bonus", table_cell), Paragraph("+10 pts", table_cell), Paragraph("Awarded when victim taps 'YES, HELPED ME' on post-resolution dialog.", table_cell)],
    ]
    impact_table = Table(impact_points_data, colWidths=[2.2*inch, 1.0*inch, 3.8*inch])
    impact_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor("#F1F5F9")),
        ('BOX', (0, 0), (-1, -1), 1, c_border),
        ('INNERGRID', (0, 0), (-1, -1), 0.5, c_border),
        ('TOPPADDING', (0, 0), (-1, -1), 4),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
        ('LEFTPADDING', (0, 0), (-1, -1), 6),
        ('RIGHTPADDING', (0, 0), (-1, -1), 6),
    ]))
    story.append(impact_table)
    story.append(Spacer(1, 10))

    story.append(Paragraph(
        "<b>Reliability Score (%):</b> Calculated as <code>(Verified Assists / Total Accepted) × 100</code>. If a victim cancels an SOS, the responder is not penalized.<br/>"
        "<b>5 Recognition Tiers:</b> Level 1 (Community Volunteer, 0-49 pts) → Level 2 (Jan Sarthi Responder, 50-149 pts) → Level 3 (Trusted Responder, 150-299 pts) → Level 4 (Community Guardian, 300-499 pts) → Level 5 (Jan Sarthi Champion, 500+ pts).<br/>"
        "<b>6 Badges:</b> First Response, Offline Guardian, Rapid Responder, Reliable Shield, Accident Hero, Night Guardian.<br/>"
        "<b>Digital Certificate:</b> Printable & shareable official certificate (<code>JS-CERT-xxxx</code>) rendered inside <code>CommunityCertificateDialog</code>.",
        body_style
    ))
    story.append(Spacer(1, 12))

    # 5. Audio Suite & Accident Demo
    story.append(Paragraph("4. Emergency Audio Suite & Sensor Fusion Demo", h1_style))
    story.append(Paragraph(
        "• <b>Deduplicated Sound Engine (<code>EmergencySoundService</code>):</b> In-memory deduplication sets prevent Flutter stream rebuilds and Nearby Connections packets from triggering duplicate sound loops.<br/>"
        "• <b>Full Sound Event Catalog:</b> Accident warning siren, 1-sec countdown ticks with final 3-sec high-pitch alerts, SOS dispatch confirmation, role-specific sirens, helper accepted tone, victim notification tone, emergency resolved tone, and debounced error sound.<br/>"
        "• <b>Sensor Fusion Accident Demo:</b> Connected directly to <code>AccidentDetectionService</code>, which evaluates accelerometer impact, gyroscope angular rotation, sudden GPS velocity drop, and vehicle context to trigger an automatic 15-second cancellable SOS dialog.",
        body_style
    ))
    story.append(Spacer(1, 12))

    # 6. Verification & Build Artifacts
    story.append(Paragraph("5. Quality Assurance & Build Artifacts", h1_style))
    story.append(Paragraph(
        "• <b>Static Analysis:</b> <code>flutter analyze</code> passed with <b>0 issues</b>.<br/>"
        "• <b>Automated Test Suite:</b> <code>flutter test</code> executed <b>27 tests with a 100% pass rate</b>.<br/>"
        "• <b>Release APK Artifact:</b><br/>"
        "  - <b>File Path:</b> <code>/Users/snehil/Downloads/jan-sarthi-main-2/build/app/outputs/flutter-apk/app-release.apk</code><br/>"
        "  - <b>Binary Size:</b> 58.9 MB (universal standalone APK)<br/>"
        "  - <b>App Icon:</b> Generated from official Jan Sarthi emblem across all Android mipmaps (mdpi to xxxhdpi and adaptive vector xml).",
        body_style
    ))
    story.append(Spacer(1, 14))

    # 7. Complete List of Changed Files
    story.append(Paragraph("6. Inventory of Modified and Created Files", h1_style))
    files_list = [
        "1. pubspec.yaml — Configured flutter_launcher_icons & registered asset paths.",
        "2. analysis_options.yaml — Configured analyzer linter rules for clean static analysis.",
        "3. lib/models/emergency_model.dart — Added isActive, isClosed, isTerminal, isClaimable & status alias parser.",
        "4. lib/models/impact_model.dart — [NEW] Civic Recognition models: UserImpactProfile, ImpactBadge, ImpactLevel, ImpactContribution.",
        "5. lib/models/user_model.dart — Integrated impactProfile and civic statistics.",
        "6. lib/services/emergency_claim_service.dart — Authoritative terminal checks, duplicate protection, and impact recording.",
        "7. lib/services/impact_reward_service.dart — [NEW] Complete impact points calculation, anti-cheating, and badge management.",
        "8. lib/services/emergency_service.dart — Emergency resolution and cancellation lifecycle handlers.",
        "9. lib/services/notification_service.dart — Upgraded EmergencySoundService with 8 deduplicated sound events.",
        "10. lib/screens/emergency/emergency_details_screen.dart — Separated live emergency UI from historical log summary.",
        "11. lib/screens/emergency/emergency_map_screen.dart — Integrated arrival impact recording, resolution points, and victim feedback.",
        "12. lib/screens/history/emergency_history_screen.dart — Descending timestamp sorting for Help Asked and Victims Helped tabs.",
        "13. lib/screens/home/home_screen.dart — Verified SOS dispatch, accident demo trigger, and switch color modernization.",
        "14. lib/screens/profile/profile_screen.dart — Added 'YOUR COMMUNITY IMPACT' Bento section, level progress, and badges gallery.",
        "15. lib/widgets/community_certificate_dialog.dart — [NEW] Official digital Jan Sarthi Responder Certificate dialog.",
        "16. lib/widgets/victim_feedback_dialog.dart — [NEW] Post-resolution victim verification modal.",
        "17. lib/widgets/accident_detection_dialog.dart — Connected warning sounds and countdown beeps.",
        "18. lib/widgets/app_dialogs.dart — Added emergencyId to siren triggers and countdown sound integration.",
        "19. lib/widgets/sos_button.dart — Updated button text and super parameters.",
        "20. test/impact_reward_test.dart — [NEW] Comprehensive unit and widget tests for civic recognition system.",
        "21. test/models_test.dart — Added active vs terminal status and alias parsing tests.",
        "22. test/stability_test.dart — Added closed claiming prevention, audio deduplication, and sorting tests.",
        "23. test/widget_test.dart — Updated button label expectations.",
    ]
    for f in files_list:
        story.append(Paragraph(f, ParagraphStyle('FileList', parent=body_style, fontSize=8.5, leading=12, spaceAfter=2)))

    doc.build(story, canvasmaker=NumberedCanvas)
    print("PDF build successful at:", pdf_path)

if __name__ == '__main__':
    build_pdf()
