import { Navigate, type RouteObject } from 'react-router';
import { parseAppEnv } from '../lib/env';
import { NotFoundView, RouteErrorPage } from '../pages/common/StatePages';
import { NoPortalPage, RequirePortal, RootRedirect } from './guards';
import { lazyScreen } from './lazyScreen';

// Tách gói tải theo cổng và theo màn: vào cổng nào chỉ tải khung của cổng đó, mở màn nào chỉ tải màn đó.
const CrmShell = lazyScreen(() => import('../layout/CrmShell'), 'CrmShell');
const TeacherShell = lazyScreen(() => import('../layout/TabShell'), 'TeacherShell');
const SessionStepsPage = lazyScreen(
  () => import('../pages/gv/SessionStepsPage'),
  'SessionStepsPage',
);
const SessionContentPage = lazyScreen(
  () => import('../pages/gv/SessionContentPage'),
  'SessionContentPage',
);
const StudentShell = lazyScreen(() => import('../layout/TabShell'), 'StudentShell');
const ParentShell = lazyScreen(() => import('../layout/TabShell'), 'ParentShell');
const LoginPage = lazyScreen(() => import('../pages/auth/LoginPages'), 'LoginPage');
const StudentLoginPage = lazyScreen(() => import('../pages/auth/LoginPages'), 'StudentLoginPage');
const ParentLoginPage = lazyScreen(() => import('../pages/auth/LoginPages'), 'ParentLoginPage');
const MfaSetupPage = lazyScreen(() => import('../pages/auth/MfaPages'), 'MfaSetupPage');
const MfaVerifyPage = lazyScreen(() => import('../pages/auth/MfaPages'), 'MfaVerifyPage');
const CannotLoginPage = lazyScreen(() => import('../pages/auth/PasswordPages'), 'CannotLoginPage');
const ChangePasswordPage = lazyScreen(
  () => import('../pages/auth/PasswordPages'),
  'ChangePasswordPage',
);
const ForgotPasswordPage = lazyScreen(
  () => import('../pages/auth/PasswordPages'),
  'ForgotPasswordPage',
);
const ResetPasswordPage = lazyScreen(
  () => import('../pages/auth/PasswordPages'),
  'ResetPasswordPage',
);
const ChoosePortalPage = lazyScreen(
  () => import('../pages/common/ChoosePortalPage'),
  'ChoosePortalPage',
);
const EnrollmentListPage = lazyScreen(
  () => import('../pages/ghi-danh/EnrollmentListPage'),
  'EnrollmentListPage',
);
const EnrollmentQueuePage = lazyScreen(
  () => import('../pages/ghi-danh/EnrollmentQueuePage'),
  'EnrollmentQueuePage',
);
const EnrollmentRecordPage = lazyScreen(
  () => import('../pages/ghi-danh/EnrollmentRecordPage'),
  'EnrollmentRecordPage',
);
const EnrollmentLedgerPage = lazyScreen(
  () => import('../pages/ghi-danh/EnrollmentLedgerPage'),
  'EnrollmentLedgerPage',
);
const TeacherAttendancePage = lazyScreen(
  () => import('../pages/gv/TeacherAttendancePage'),
  'TeacherAttendancePage',
);
const TeacherTodayPage = lazyScreen(
  () => import('../pages/gv/TeacherTodayPage'),
  'TeacherTodayPage',
);
const SessionListPage = lazyScreen(
  () => import('../pages/buoi/SessionListPage'),
  'SessionListPage',
);
const SessionRecordPage = lazyScreen(
  () => import('../pages/buoi/SessionRecordPage'),
  'SessionRecordPage',
);
const SessionOpsPage = lazyScreen(() => import('../pages/buoi/SessionOpsPage'), 'SessionOpsPage');
const SessionPendingPage = lazyScreen(
  () => import('../pages/buoi/SessionPendingPage'),
  'SessionPendingPage',
);
const AttendancePage = lazyScreen(
  () => import('../pages/diem-danh/AttendancePage'),
  'AttendancePage',
);
const HomeworkGradingPage = lazyScreen(
  () => import('../pages/gv/HomeworkGradingPage'),
  'HomeworkGradingPage',
);
const ReviewGradingPage = lazyScreen(
  () => import('../pages/gv/ReviewGradingPage'),
  'ReviewGradingPage',
);
const ExamGradingPage = lazyScreen(() => import('../pages/gv/ExamGradingPage'), 'ExamGradingPage');
const CrmHome = lazyScreen(() => import('../pages/home/CrmHome'), 'CrmHome');
const CrmSectionPage = lazyScreen(() => import('../pages/common/PortalPages'), 'CrmSectionPage');
const MyWorkPage = lazyScreen(() => import('../pages/viec-cua-toi/MyWorkPage'), 'MyWorkPage');
const ApprovalsPage = lazyScreen(
  () => import('../pages/viec-cho-duyet/ApprovalsPage'),
  'ApprovalsPage',
);
const UpsaleRecordPage = lazyScreen(
  () => import('../pages/tai-tuc/UpsaleRecordPage'),
  'UpsaleRecordPage',
);
const UpsaleListPage = lazyScreen(
  () => import('../pages/tai-tuc/UpsaleListPage'),
  'UpsaleListPage',
);
const ReconcilePage = lazyScreen(() => import('../pages/tai-tuc/ReconcilePage'), 'ReconcilePage');
const TicketListPage = lazyScreen(() => import('../pages/ticket/TicketListPage'), 'TicketListPage');
const TicketRecordPage = lazyScreen(
  () => import('../pages/ticket/TicketRecordPage'),
  'TicketRecordPage',
);
const TicketCreatePage = lazyScreen(
  () => import('../pages/ticket/TicketCreatePage'),
  'TicketCreatePage',
);
const TicketSlaPage = lazyScreen(() => import('../pages/ticket/TicketSlaPage'), 'TicketSlaPage');
const TicketCategoriesPage = lazyScreen(
  () => import('../pages/ticket/TicketCategoriesPage'),
  'TicketCategoriesPage',
);
const BranchRoomPage = lazyScreen(() => import('../pages/co-so/BranchRoomPage'), 'BranchRoomPage');
const TeachingProfilePage = lazyScreen(
  () => import('../pages/ho-so-day/TeachingProfilePage'),
  'TeachingProfilePage',
);
const TaskListPage = lazyScreen(() => import('../pages/phieu/TaskListPage'), 'TaskListPage');
const TaskDestinationListPage = lazyScreen(
  () => import('../pages/phieu-den/TaskDestinationListPage'),
  'TaskDestinationListPage',
);
const TaskDestinationPage = lazyScreen(
  () => import('../pages/phieu-den/TaskDestinationPage'),
  'TaskDestinationPage',
);
const ParentMessageListPage = lazyScreen(
  () => import('../pages/nhan-xet-cho-gui/ParentMessageListPage'),
  'ParentMessageListPage',
);
const TaskRecordPage = lazyScreen(() => import('../pages/phieu/TaskRecordPage'), 'TaskRecordPage');
const GatedCrmEntry = lazyScreen(() => import('../pages/common/PortalPages'), 'GatedCrmEntry');
const LeadListPage = lazyScreen(() => import('../pages/lead/LeadListPage'), 'LeadListPage');
const OpportunityListPage = lazyScreen(
  () => import('../pages/co-hoi/OpportunityListPage'),
  'OpportunityListPage',
);
const QuotationListPage = lazyScreen(
  () => import('../pages/bao-gia/QuotationListPage'),
  'QuotationListPage',
);
const ReceiptRecordPage = lazyScreen(
  () => import('../pages/phieu-thu/ReceiptRecordPage'),
  'ReceiptRecordPage',
);
const ReceiptPrintPage = lazyScreen(
  () => import('../pages/phieu-thu/ReceiptPrintPage'),
  'ReceiptPrintPage',
);
const MoneyInListPage = lazyScreen(
  () => import('../pages/thu-tien/TreasuryListPages'),
  'MoneyInListPage',
);
const ReceivableListPage = lazyScreen(
  () => import('../pages/thu-tien/TreasuryListPages'),
  'ReceivableListPage',
);
const ApproverConfigPage = lazyScreen(
  () => import('../pages/nguoi-duyet-ticket/ApproverConfigPage'),
  'ApproverConfigPage',
);
const ReceiptReconcilePage = lazyScreen(
  () => import('../pages/doi-soat/ReceiptReconcilePage'),
  'ReceiptReconcilePage',
);
const ReceiptListPage = lazyScreen(
  () => import('../pages/phieu-thu/ReceiptListPage'),
  'ReceiptListPage',
);
const VoucherListPage = lazyScreen(
  () => import('../pages/phieu-chi/VoucherListPage'),
  'VoucherListPage',
);
const VoucherRecordPage = lazyScreen(
  () => import('../pages/phieu-chi/VoucherRecordPage'),
  'VoucherRecordPage',
);
const VoucherPrintPage = lazyScreen(
  () => import('../pages/phieu-chi/VoucherPrintPage'),
  'VoucherPrintPage',
);
const BalanceListPage = lazyScreen(
  () => import('../pages/so-du/BalanceListPage'),
  'BalanceListPage',
);
const BalanceHistoryPage = lazyScreen(
  () => import('../pages/so-du/BalanceHistoryPage'),
  'BalanceHistoryPage',
);
const SessionRequestListPage = lazyScreen(
  () => import('../pages/yeu-cau-buoi/SessionRequestListPage'),
  'SessionRequestListPage',
);
const SessionRequestMakeupPage = lazyScreen(
  () => import('../pages/yeu-cau-buoi/SessionRequestMakeupPage'),
  'SessionRequestMakeupPage',
);
const SessionRequestSupportPage = lazyScreen(
  () => import('../pages/yeu-cau-buoi/SessionRequestSupportPage'),
  'SessionRequestSupportPage',
);
const SessionRequestCreatePage = lazyScreen(
  () => import('../pages/yeu-cau-buoi/SessionRequestCreatePage'),
  'SessionRequestCreatePage',
);
const OrderCreatePage = lazyScreen(
  () => import('../pages/don-hang/OrderCreatePage'),
  'OrderCreatePage',
);
const OrderListPage = lazyScreen(() => import('../pages/don-hang/OrderListPage'), 'OrderListPage');
const OrderRecordPage = lazyScreen(
  () => import('../pages/don-hang/OrderRecordPage'),
  'OrderRecordPage',
);
const QuotationCreatePage = lazyScreen(
  () => import('../pages/bao-gia/QuotationCreatePage'),
  'QuotationCreatePage',
);
const QuotationRecordPage = lazyScreen(
  () => import('../pages/bao-gia/QuotationRecordPage'),
  'QuotationRecordPage',
);
const QuotationPrintPage = lazyScreen(
  () => import('../pages/bao-gia/QuotationPrintPage'),
  'QuotationPrintPage',
);
const OpportunityRecordPage = lazyScreen(
  () => import('../pages/co-hoi/OpportunityRecordPage'),
  'OpportunityRecordPage',
);
const ImportDataPage = lazyScreen(
  () => import('../pages/nhap-du-lieu/ImportDataPage'),
  'ImportDataPage',
);
const CatalogPage = lazyScreen(() => import('../pages/danh-muc/CatalogPage'), 'CatalogPage');
const RoleListPage = lazyScreen(() => import('../pages/vai-tro/RoleListPage'), 'RoleListPage');
const LateTeachersPage = lazyScreen(
  () => import('../pages/bao-cao-tre-han/LateTeachersPage'),
  'LateTeachersPage',
);
const LoginLogPage = lazyScreen(
  () => import('../pages/nhat-ky-dang-nhap/LoginLogPage'),
  'LoginLogPage',
);
const AuditLogPage = lazyScreen(() => import('../pages/nhat-ky/AuditLogPage'), 'AuditLogPage');
const TeachingHoursPage = lazyScreen(
  () => import('../pages/bao-cao-gio-day/TeachingHoursPage'),
  'TeachingHoursPage',
);
const OverviewPage = lazyScreen(() => import('../pages/bao-cao/OverviewPage'), 'OverviewPage');
const PermissionMatrixPage = lazyScreen(
  () => import('../pages/ma-tran/PermissionMatrixPage'),
  'PermissionMatrixPage',
);
const RubricPage = lazyScreen(() => import('../pages/rubric/RubricPage'), 'RubricPage');
const CampaignPage = lazyScreen(() => import('../pages/chien-dich/CampaignPage'), 'CampaignPage');
const HolidayPage = lazyScreen(() => import('../pages/ngay-nghi/HolidayPage'), 'HolidayPage');
const LessonListPage = lazyScreen(
  () => import('../pages/khung-chuong-trinh/LessonListPage'),
  'LessonListPage',
);
const CurriculumFramePage = lazyScreen(
  () => import('../pages/khung-chuong-trinh/CurriculumFramePage'),
  'CurriculumFramePage',
);
const DiscountPolicyPage = lazyScreen(
  () => import('../pages/chiet-khau/DiscountPolicyPage'),
  'DiscountPolicyPage',
);
const PaymentTermPage = lazyScreen(
  () => import('../pages/dieu-khoan/PaymentTermPage'),
  'PaymentTermPage',
);
const FeatureFlagsPage = lazyScreen(
  () => import('../pages/cong-tac/FeatureFlagsPage'),
  'FeatureFlagsPage',
);
const SettingsPage = lazyScreen(() => import('../pages/tham-so/SettingsPage'), 'SettingsPage');
const PackageRecordPage = lazyScreen(
  () => import('../pages/goi-ban/PackageRecordPage'),
  'PackageRecordPage',
);
const PackageListPage = lazyScreen(
  () => import('../pages/goi-ban/PackageListPage'),
  'PackageListPage',
);
const PriceListPage = lazyScreen(() => import('../pages/bang-gia/PriceListPage'), 'PriceListPage');
const UserListPage = lazyScreen(() => import('../pages/nguoi-dung/UserListPage'), 'UserListPage');
const ParentAccountPage = lazyScreen(
  () => import('../pages/tai-khoan-phu-huynh/ParentAccountPage'),
  'ParentAccountPage',
);
const StudentAccountPage = lazyScreen(
  () => import('../pages/tai-khoan-hoc-sinh/StudentAccountPage'),
  'StudentAccountPage',
);
const GradePromotionPage = lazyScreen(
  () => import('../pages/len-khoi/GradePromotionPage'),
  'GradePromotionPage',
);
const UserRecordPage = lazyScreen(
  () => import('../pages/nguoi-dung/UserRecordPage'),
  'UserRecordPage',
);
const ClassListPage = lazyScreen(() => import('../pages/lop/ClassListPage'), 'ClassListPage');
const ClassFormPage = lazyScreen(() => import('../pages/lop/ClassFormPage'), 'ClassFormPage');
const ClassStudentsPage = lazyScreen(
  () => import('../pages/lop/ClassStudentsPage'),
  'ClassStudentsPage',
);
const ClassRecordPage = lazyScreen(() => import('../pages/lop/ClassRecordPage'), 'ClassRecordPage');
const WeekCalendarPage = lazyScreen(
  () => import('../pages/lop/WeekCalendarPage'),
  'WeekCalendarPage',
);
const ParentListPage = lazyScreen(
  () => import('../pages/khach-hang/CustomerListPages'),
  'ParentListPage',
);
const StudentListPage = lazyScreen(
  () => import('../pages/khach-hang/CustomerListPages'),
  'StudentListPage',
);
const ParentRecordPage = lazyScreen(
  () => import('../pages/khach-hang/ParentRecordPage'),
  'ParentRecordPage',
);
const StudentRecordPage = lazyScreen(
  () => import('../pages/khach-hang/StudentRecordPage'),
  'StudentRecordPage',
);
const TestListPage = lazyScreen(() => import('../pages/phieu/TestListPage'), 'TestListPage');
const TestRecordPage = lazyScreen(() => import('../pages/phieu/TestRecordPage'), 'TestRecordPage');
const AppointmentListPage = lazyScreen(
  () => import('../pages/lich-hen/AppointmentListPage'),
  'AppointmentListPage',
);
const LeadRecordPage = lazyScreen(() => import('../pages/lead/LeadRecordPage'), 'LeadRecordPage');
const TestGradingPage = lazyScreen(() => import('../pages/gv/TestGradingPage'), 'TestGradingPage');
const TeacherTodoPage = lazyScreen(() => import('../pages/gv/TeacherTodoPage'), 'TeacherTodoPage');
const TeacherClassesPage = lazyScreen(
  () => import('../pages/gv/TeacherClassesPage'),
  'TeacherClassesPage',
);
const TeacherClassPage = lazyScreen(
  () => import('../pages/gv/TeacherClassPage'),
  'TeacherClassPage',
);
const TeacherHoursPage = lazyScreen(
  () => import('../pages/gv/TeacherHoursPage'),
  'TeacherHoursPage',
);
const TeacherStudentPage = lazyScreen(
  () => import('../pages/gv/TeacherStudentPage'),
  'TeacherStudentPage',
);
const ExpiringListPage = lazyScreen(
  () => import('../pages/sap-het-gio/ExpiringListPage'),
  'ExpiringListPage',
);
const LmsGradingListPage = lazyScreen(
  () => import('../pages/gv/LmsGradingListPage'),
  'LmsGradingListPage',
);
const LmsGradingPage = lazyScreen(() => import('../pages/gv/LmsGradingPage'), 'LmsGradingPage');
const TeacherTicketsPage = lazyScreen(
  () => import('../pages/gv/TeacherTicketsPage'),
  'TeacherTicketsPage',
);
const LmsAssignmentsPage = lazyScreen(
  () => import('../pages/gv/LmsAssignmentsPage'),
  'LmsAssignmentsPage',
);
const LmsAssignmentFormPage = lazyScreen(
  () => import('../pages/gv/LmsAssignmentFormPage'),
  'LmsAssignmentFormPage',
);
const TeacherTicketCreatePage = lazyScreen(
  () => import('../pages/gv/TeacherTicketCreatePage'),
  'TeacherTicketCreatePage',
);
const TeacherSchedulePage = lazyScreen(
  () => import('../pages/gv/TeacherSchedulePage'),
  'TeacherSchedulePage',
);
const ParentHomePage = lazyScreen(() => import('../pages/ph/ParentHomePage'), 'ParentHomePage');
const StudentSchedulePage = lazyScreen(
  () => import('../pages/hoc/StudentSchedulePage'),
  'StudentSchedulePage',
);
const StudentResultsPage = lazyScreen(
  () => import('../pages/hoc/StudentResultsPage'),
  'StudentResultsPage',
);
const StudentReviewsPage = lazyScreen(
  () => import('../pages/hoc/StudentReviewsPage'),
  'StudentReviewsPage',
);
const StudentHomePage = lazyScreen(() => import('../pages/hoc/StudentHomePage'), 'StudentHomePage');
const StudentAssignmentsPage = lazyScreen(
  () => import('../pages/hoc/StudentAssignmentsPage'),
  'StudentAssignmentsPage',
);
const StudentAssignmentPage = lazyScreen(
  () => import('../pages/hoc/StudentAssignmentPage'),
  'StudentAssignmentPage',
);
const ParentResultsPage = lazyScreen(
  () => import('../pages/ph/ParentResultsPage'),
  'ParentResultsPage',
);
const ParentRequestsPage = lazyScreen(
  () => import('../pages/ph/ParentRequestsPages'),
  'ParentRequestsPage',
);
const ParentRequestNewPage = lazyScreen(
  () => import('../pages/ph/ParentRequestsPages'),
  'ParentRequestNewPage',
);
const ParentRequestDetailPage = lazyScreen(
  () => import('../pages/ph/ParentRequestsPages'),
  'ParentRequestDetailPage',
);
const ParentSchedulePage = lazyScreen(
  () => import('../pages/ph/ParentSchedulePage'),
  'ParentSchedulePage',
);
const ParentFeesPage = lazyScreen(() => import('../pages/ph/ParentFeesPage'), 'ParentFeesPage');
const ParentOrderPage = lazyScreen(() => import('../pages/ph/ParentOrderPage'), 'ParentOrderPage');
const ProfilePage = lazyScreen(() => import('../pages/common/ProfilePage'), 'ProfilePage');
const DemoDataPage = lazyScreen(() => import('../pages/du-lieu-mau/DemoDataPage'), 'DemoDataPage');
const GuidePage = lazyScreen(() => import('../pages/huong-dan/GuidePage'), 'GuidePage');
const HomePage = lazyScreen(() => import('../pages/HomePage'), 'HomePage');
const DetailDemoPage = lazyScreen(() => import('../pages/dev/DetailDemoPage'), 'DetailDemoPage');
const DialogsDemoPage = lazyScreen(() => import('../pages/dev/DialogsDemoPage'), 'DialogsDemoPage');
const ListDemoPage = lazyScreen(() => import('../pages/dev/ListDemoPage'), 'ListDemoPage');
const PatternPage = lazyScreen(() => import('../pages/dev/PatternPage'), 'PatternPage');

// Trang mẫu thành phần: chỉ có ở bản thử nghiệm, xem trước và local; bản chạy thật không có route này.
const SHOW_PATTERNS = parseAppEnv(import.meta.env.VITE_APP_ENV) !== 'production';

export const routes: RouteObject[] = [
  {
    path: '/',
    errorElement: <RouteErrorPage />,
    children: [
      { index: true, element: <RootRedirect /> },
      // Đăng nhập và các bước bắt buộc (khuôn K11).
      { path: 'dang-nhap', element: <LoginPage /> },
      { path: 'dang-nhap/hoc-sinh', element: <StudentLoginPage /> },
      { path: 'dang-nhap/phu-huynh', element: <ParentLoginPage /> },
      { path: 'xac-thuc-hai-buoc', element: <MfaVerifyPage /> },
      { path: 'thiet-lap-hai-buoc', element: <MfaSetupPage /> },
      { path: 'quen-mat-khau', element: <ForgotPasswordPage /> },
      { path: 'dat-mat-khau', element: <ResetPasswordPage /> },
      { path: 'doi-mat-khau', element: <ChangePasswordPage /> },
      { path: 'khong-dang-nhap-duoc', element: <CannotLoginPage /> },
      { path: 'chon-cong', element: <ChoosePortalPage /> },
      { path: 'khong-co-quyen', element: <NoPortalPage /> },
      ...(SHOW_PATTERNS
        ? [
            {
              path: 'dev',
              element: (
                <RequirePortal portal="crm">
                  <CrmShell />
                </RequirePortal>
              ),
              children: [
                { path: 'khuon', element: <PatternPage /> },
                { path: 'danh-sach', element: <ListDemoPage /> },
                { path: 'chi-tiet', element: <DetailDemoPage /> },
                { path: 'hop-thoai', element: <DialogsDemoPage /> },
              ],
            } satisfies RouteObject,
          ]
        : []),
      // Trang kiểm tra kết nối (bước 1), không nằm trong menu.
      { path: 'trang-thai', element: <HomePage /> },
      {
        path: 'crm',
        element: (
          <RequirePortal portal="crm">
            <CrmShell />
          </RequirePortal>
        ),
        children: [
          { index: true, element: <CrmHome /> },
          { path: 'huong-dan/:slug?', element: <GuidePage /> },
          { path: 'tai-khoan', element: <ProfilePage /> },
          { path: 'du-lieu-mau', element: <DemoDataPage /> },
          {
            path: 'lead',
            element: (
              <GatedCrmEntry slug="lead">
                <LeadListPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'lead/moi',
            element: (
              <GatedCrmEntry slug="lead" need={['LEAD', 'TAO']}>
                <LeadRecordPage creating />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'lead/:id',
            element: (
              <GatedCrmEntry slug="lead">
                <LeadRecordPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'co-hoi',
            element: (
              <GatedCrmEntry slug="co-hoi">
                <OpportunityListPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'co-hoi/:id',
            element: (
              <GatedCrmEntry slug="co-hoi">
                <OpportunityRecordPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'bao-gia',
            element: (
              <GatedCrmEntry slug="bao-gia">
                <QuotationListPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'phieu-thu',
            element: (
              <GatedCrmEntry slug="phieu-thu">
                <ReceiptListPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'phieu-thu/:id/in',
            element: (
              <GatedCrmEntry slug="phieu-thu">
                <ReceiptPrintPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'phieu-thu/:id',
            element: (
              <GatedCrmEntry slug="phieu-thu">
                <ReceiptRecordPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'phieu-chi',
            element: (
              <GatedCrmEntry slug="phieu-chi">
                <VoucherListPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'phieu-chi/:id/in',
            element: (
              <GatedCrmEntry slug="phieu-chi">
                <VoucherPrintPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'phieu-chi/:id',
            element: (
              <GatedCrmEntry slug="phieu-chi">
                <VoucherRecordPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'so-du-khach-hang',
            element: (
              <GatedCrmEntry slug="so-du-khach-hang">
                <BalanceListPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'so-du-khach-hang/:parentId',
            element: (
              <GatedCrmEntry slug="so-du-khach-hang">
                <BalanceHistoryPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'khoan-tien-vao',
            element: (
              <GatedCrmEntry slug="khoan-tien-vao">
                <MoneyInListPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'doi-soat-thu-tien',
            element: (
              <GatedCrmEntry slug="doi-soat-thu-tien">
                <ReceiptReconcilePage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'cong-no',
            element: (
              <GatedCrmEntry slug="cong-no">
                <ReceivableListPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'cho-ke-toan-duyet',
            element: (
              <GatedCrmEntry slug="cho-ke-toan-duyet">
                <ReceiptListPage waitingAccounting />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'viec-cua-toi',
            element: (
              <GatedCrmEntry slug="viec-cua-toi">
                <MyWorkPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'viec-cho-duyet',
            element: (
              <GatedCrmEntry slug="viec-cho-duyet">
                <ApprovalsPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'tai-tuc',
            element: (
              <GatedCrmEntry slug="tai-tuc">
                <UpsaleListPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'tai-tuc/:id',
            element: (
              <GatedCrmEntry slug="tai-tuc">
                <UpsaleRecordPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'doi-chieu-tai-tuc',
            element: (
              <GatedCrmEntry slug="doi-chieu-tai-tuc">
                <ReconcilePage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'ticket',
            element: (
              <GatedCrmEntry slug="ticket">
                <TicketListPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'phieu-nghiep-vu',
            element: (
              <GatedCrmEntry slug="phieu-nghiep-vu">
                <TaskListPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'phieu-chuyen-co-so-den',
            element: (
              <GatedCrmEntry slug="phieu-chuyen-co-so-den">
                <TaskDestinationListPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'phieu-chuyen-co-so-den/:id',
            element: (
              <GatedCrmEntry slug="phieu-chuyen-co-so-den">
                <TaskDestinationPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'nhan-xet-cho-gui',
            element: (
              <GatedCrmEntry slug="nhan-xet-cho-gui">
                <ParentMessageListPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'phieu-nghiep-vu/:id',
            element: (
              <GatedCrmEntry slug="phieu-nghiep-vu">
                <TaskRecordPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'ticket/moi',
            element: (
              <GatedCrmEntry slug="ticket">
                <TicketCreatePage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'ticket/:id',
            element: (
              <GatedCrmEntry slug="ticket">
                <TicketRecordPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'ghi-danh',
            element: (
              <GatedCrmEntry slug="ghi-danh">
                <EnrollmentListPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'ghi-danh/:id',
            element: (
              <GatedCrmEntry slug="ghi-danh">
                <EnrollmentRecordPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'ghi-danh/:id/so-gio',
            element: (
              <GatedCrmEntry slug="ghi-danh">
                <EnrollmentLedgerPage />
              </GatedCrmEntry>
            ),
          },
          // Đường cũ của «Điểm danh trong ngày» chuyển sang màn «Điểm danh».
          { path: 'diem-danh-trong-ngay', element: <Navigate to="/crm/diem-danh" replace /> },
          {
            path: 'sap-het-gio',
            element: (
              <GatedCrmEntry slug="sap-het-gio">
                <ExpiringListPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'cho-xep-lop',
            element: (
              <GatedCrmEntry slug="cho-xep-lop">
                <EnrollmentQueuePage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'buoi-hoc',
            element: (
              <GatedCrmEntry slug="buoi-hoc">
                <SessionListPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'buoi-hoc/:id',
            element: (
              <GatedCrmEntry slug="buoi-hoc">
                <SessionRecordPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'yeu-cau-buoi',
            element: (
              <GatedCrmEntry slug="yeu-cau-buoi">
                <SessionRequestListPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'yeu-cau-buoi/tao-hoc-bu',
            element: (
              <GatedCrmEntry slug="yeu-cau-buoi">
                <SessionRequestMakeupPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'yeu-cau-buoi/tao-bo-tro',
            element: (
              <GatedCrmEntry slug="yeu-cau-buoi">
                <SessionRequestSupportPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'yeu-cau-buoi/tao-cung-co',
            element: (
              <GatedCrmEntry slug="yeu-cau-buoi">
                <SessionRequestCreatePage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'buoi-chua-done',
            element: (
              <GatedCrmEntry slug="buoi-chua-done">
                <SessionPendingPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'diem-danh',
            element: (
              <GatedCrmEntry slug="diem-danh">
                <AttendancePage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'diem-danh/buoi/:id',
            element: (
              <GatedCrmEntry slug="diem-danh">
                <SessionOpsPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'don-hang',
            element: (
              <GatedCrmEntry slug="don-hang">
                <OrderListPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'don-hang/:id',
            element: (
              <GatedCrmEntry slug="don-hang">
                <OrderRecordPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'don-hang/tao',
            element: (
              <GatedCrmEntry slug="don-hang">
                <OrderCreatePage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'bao-gia/tao',
            element: (
              <GatedCrmEntry slug="bao-gia">
                <QuotationCreatePage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'bao-gia/:id/in',
            element: (
              <GatedCrmEntry slug="bao-gia">
                <QuotationPrintPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'bao-gia/:id',
            element: (
              <GatedCrmEntry slug="bao-gia">
                <QuotationRecordPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'phieu-kiem-tra',
            element: (
              <GatedCrmEntry slug="phieu-kiem-tra">
                <TestListPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'phieu-kiem-tra/:id',
            element: (
              <GatedCrmEntry slug="phieu-kiem-tra">
                <TestRecordPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'quan-tri/nhap-du-lieu',
            element: (
              <GatedCrmEntry slug="quan-tri/nhap-du-lieu">
                <ImportDataPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'cau-hinh/nhom-ticket',
            element: (
              <GatedCrmEntry slug="cau-hinh/nhom-ticket">
                <TicketCategoriesPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'cau-hinh/sla-ticket',
            element: (
              <GatedCrmEntry slug="cau-hinh/sla-ticket">
                <TicketSlaPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'cau-hinh/goi-ban',
            element: (
              <GatedCrmEntry slug="cau-hinh/goi-ban">
                <PackageListPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'cau-hinh/goi-ban/:id',
            element: (
              <GatedCrmEntry slug="cau-hinh/goi-ban">
                <PackageRecordPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'cau-hinh/bang-gia',
            element: (
              <GatedCrmEntry slug="cau-hinh/bang-gia">
                <PriceListPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'quan-tri/danh-muc',
            element: (
              <GatedCrmEntry slug="quan-tri/danh-muc">
                <CatalogPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'quan-tri/ma-tran-quyen',
            element: (
              <GatedCrmEntry slug="quan-tri/ma-tran-quyen">
                <PermissionMatrixPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'quan-tri/co-so',
            element: (
              <GatedCrmEntry slug="quan-tri/co-so">
                <BranchRoomPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'quan-tri/giao-vien',
            element: (
              <GatedCrmEntry slug="quan-tri/giao-vien">
                <TeachingProfilePage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'cau-hinh/rubric',
            element: (
              <GatedCrmEntry slug="cau-hinh/rubric">
                <RubricPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'cau-hinh/khung-chuong-trinh/:id',
            element: (
              <GatedCrmEntry slug="cau-hinh/khung-chuong-trinh">
                <LessonListPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'cau-hinh/khung-chuong-trinh',
            element: (
              <GatedCrmEntry slug="cau-hinh/khung-chuong-trinh">
                <CurriculumFramePage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'cau-hinh/ngay-nghi',
            element: (
              <GatedCrmEntry slug="cau-hinh/ngay-nghi">
                <HolidayPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'cau-hinh/nguoi-duyet-ticket',
            element: (
              <GatedCrmEntry slug="cau-hinh/nguoi-duyet-ticket">
                <ApproverConfigPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'cau-hinh/chiet-khau',
            element: (
              <GatedCrmEntry slug="cau-hinh/chiet-khau">
                <DiscountPolicyPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'cau-hinh/dieu-khoan-thanh-toan',
            element: (
              <GatedCrmEntry slug="cau-hinh/dieu-khoan-thanh-toan">
                <PaymentTermPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'quan-tri/cong-tac',
            element: (
              <GatedCrmEntry slug="quan-tri/cong-tac">
                <FeatureFlagsPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'quan-tri/tham-so',
            element: (
              <GatedCrmEntry slug="quan-tri/tham-so">
                <SettingsPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'quan-tri/nhat-ky-dang-nhap',
            element: (
              <GatedCrmEntry slug="quan-tri/nhat-ky-dang-nhap">
                <LoginLogPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'quan-tri/nhat-ky',
            element: (
              <GatedCrmEntry slug="quan-tri/nhat-ky">
                <AuditLogPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'bao-cao/giao-vien-tre-han',
            element: (
              <GatedCrmEntry slug="bao-cao/giao-vien-tre-han">
                <LateTeachersPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'bao-cao/gio-day',
            element: (
              <GatedCrmEntry slug="bao-cao/gio-day">
                <TeachingHoursPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'cau-hinh/chien-dich',
            element: (
              <GatedCrmEntry slug="cau-hinh/chien-dich">
                <CampaignPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'bao-cao/tong-quan',
            element: (
              <GatedCrmEntry slug="bao-cao/tong-quan">
                <OverviewPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'quan-tri/vai-tro',
            element: (
              <GatedCrmEntry slug="quan-tri/vai-tro">
                <RoleListPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'quan-tri/nguoi-dung',
            element: (
              <GatedCrmEntry slug="quan-tri/nguoi-dung">
                <UserListPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'quan-tri/tai-khoan-phu-huynh',
            element: (
              <GatedCrmEntry slug="quan-tri/tai-khoan-phu-huynh">
                <ParentAccountPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'quan-tri/tai-khoan-hoc-sinh',
            element: (
              <GatedCrmEntry slug="quan-tri/tai-khoan-hoc-sinh">
                <StudentAccountPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'len-khoi-dau-nam',
            element: (
              <GatedCrmEntry slug="len-khoi-dau-nam">
                <GradePromotionPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'quan-tri/nguoi-dung/:id',
            element: (
              <GatedCrmEntry slug="quan-tri/nguoi-dung">
                <UserRecordPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'lich-hen',
            element: (
              <GatedCrmEntry slug="lich-hen">
                <AppointmentListPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'lop',
            element: (
              <GatedCrmEntry slug="lop">
                <ClassListPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'lich-tuan',
            element: (
              <GatedCrmEntry slug="lich-tuan">
                <WeekCalendarPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'lop/tao',
            element: (
              <GatedCrmEntry slug="lop" need={['CLASS', 'TAO']}>
                <ClassFormPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'lop/:id/sua',
            element: (
              <GatedCrmEntry slug="lop" need={['CLASS', 'SUA']}>
                <ClassFormPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'lop/:id/hoc-sinh',
            element: (
              <GatedCrmEntry slug="lop">
                <ClassStudentsPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'lop/:id',
            element: (
              <GatedCrmEntry slug="lop">
                <ClassRecordPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'phu-huynh',
            element: (
              <GatedCrmEntry slug="phu-huynh">
                <ParentListPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'phu-huynh/:id',
            element: (
              <GatedCrmEntry slug="phu-huynh">
                <ParentRecordPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'hoc-sinh',
            element: (
              <GatedCrmEntry slug="hoc-sinh">
                <StudentListPage />
              </GatedCrmEntry>
            ),
          },
          {
            path: 'hoc-sinh/:id',
            element: (
              <GatedCrmEntry slug="hoc-sinh">
                <StudentRecordPage />
              </GatedCrmEntry>
            ),
          },
          { path: '*', element: <CrmSectionPage /> },
        ],
      },
      {
        path: 'gv',
        element: (
          <RequirePortal portal="gv">
            <TeacherShell />
          </RequirePortal>
        ),
        children: [
          { index: true, element: <TeacherTodayPage /> },
          { path: 'huong-dan/:slug?', element: <GuidePage /> },
          { path: 'lich-day', element: <TeacherSchedulePage /> },
          { path: 'gio-day', element: <TeacherHoursPage /> },
          { path: 'lop', element: <TeacherClassesPage /> },
          { path: 'lop/:classId', element: <TeacherClassPage /> },
          { path: 'lop/:classId/bai-giao', element: <LmsAssignmentsPage /> },
          { path: 'lop/:classId/bai-giao/moi', element: <LmsAssignmentFormPage /> },
          { path: 'lop/:classId/bai-giao/:assignmentId', element: <LmsAssignmentFormPage /> },
          { path: 'lop/:classId/hoc-sinh/:studentId', element: <TeacherStudentPage /> },
          { path: 'viec-can-lam', element: <TeacherTodoPage /> },
          { path: 'phieu-test/:testId', element: <TestGradingPage /> },
          { path: 'ticket', element: <TeacherTicketsPage /> },
          { path: 'lop/:classId/bai-giao/:assignmentId/cham', element: <LmsGradingListPage /> },
          {
            path: 'lop/:classId/bai-giao/:assignmentId/cham/:studentId',
            element: <LmsGradingPage />,
          },
          { path: 'ticket/tao', element: <TeacherTicketCreatePage /> },
          { path: 'buoi/:sessionId', element: <SessionStepsPage /> },
          { path: 'buoi/:sessionId/noi-dung', element: <SessionContentPage /> },
          { path: 'buoi/:sessionId/cham-btvn', element: <HomeworkGradingPage /> },
          { path: 'buoi/:sessionId/cham-nhan-xet', element: <ReviewGradingPage /> },
          { path: 'buoi/:sessionId/cham-kiem-tra', element: <ExamGradingPage /> },
          { path: 'buoi/:id/diem-danh', element: <TeacherAttendancePage /> },
          { path: 'tai-khoan', element: <ProfilePage /> },
          { path: 'du-lieu-mau', element: <DemoDataPage /> },
          { path: '*', element: <NotFoundView /> },
        ],
      },
      {
        path: 'hoc',
        element: (
          <RequirePortal portal="hoc">
            <StudentShell />
          </RequirePortal>
        ),
        children: [
          { index: true, element: <StudentHomePage /> },
          { path: 'bai-tap', element: <StudentAssignmentsPage /> },
          { path: 'bai-tap/:id', element: <StudentAssignmentPage /> },
          { path: 'lich', element: <StudentSchedulePage /> },
          { path: 'ket-qua', element: <StudentResultsPage /> },
          { path: 'ket-qua/nhan-xet', element: <StudentReviewsPage /> },
          { path: 'tai-khoan', element: <ProfilePage /> },
          { path: 'du-lieu-mau', element: <DemoDataPage /> },
          { path: '*', element: <NotFoundView /> },
        ],
      },
      {
        path: 'ph',
        element: (
          <RequirePortal portal="ph">
            <ParentShell />
          </RequirePortal>
        ),
        children: [
          { index: true, element: <ParentHomePage /> },
          { path: 'ket-qua', element: <ParentResultsPage /> },
          { path: 'ket-qua/nhan-xet', element: <ParentResultsPage /> },
          { path: 'hoc-phi', element: <ParentFeesPage /> },
          { path: 'hoc-phi/:orderId', element: <ParentOrderPage /> },
          { path: 'lich', element: <ParentSchedulePage /> },
          { path: 'de-nghi', element: <ParentRequestsPage /> },
          { path: 'de-nghi/moi', element: <ParentRequestNewPage /> },
          { path: 'de-nghi/:ticketId', element: <ParentRequestDetailPage /> },
          { path: 'tai-khoan', element: <ProfilePage /> },
          { path: 'du-lieu-mau', element: <DemoDataPage /> },
          { path: '*', element: <NotFoundView /> },
        ],
      },
      { path: '*', element: <NotFoundView /> },
    ],
  },
];
