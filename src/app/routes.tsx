import type { RouteObject } from 'react-router';
import { parseAppEnv } from '../lib/env';
import { NotFoundView, RouteErrorPage } from '../pages/common/StatePages';
import { NoPortalPage, RequirePortal, RootRedirect } from './guards';
import { lazyScreen } from './lazyScreen';

// Tách gói tải theo cổng và theo màn: vào cổng nào chỉ tải khung của cổng đó, mở màn nào chỉ tải màn đó.
const CrmShell = lazyScreen(() => import('../layout/CrmShell'), 'CrmShell');
const TeacherShell = lazyScreen(() => import('../layout/TabShell'), 'TeacherShell');
const StudentShell = lazyScreen(() => import('../layout/TabShell'), 'StudentShell');
const LoginPage = lazyScreen(() => import('../pages/auth/LoginPages'), 'LoginPage');
const StudentLoginPage = lazyScreen(() => import('../pages/auth/LoginPages'), 'StudentLoginPage');
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
const CrmHome = lazyScreen(() => import('../pages/home/CrmHome'), 'CrmHome');
const CrmSectionPage = lazyScreen(() => import('../pages/common/PortalPages'), 'CrmSectionPage');
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
const OrderListPage = lazyScreen(() => import('../pages/don-hang/OrderListPage'), 'OrderListPage');
const QuotationCreatePage = lazyScreen(
  () => import('../pages/bao-gia/QuotationCreatePage'),
  'QuotationCreatePage',
);
const QuotationRecordPage = lazyScreen(
  () => import('../pages/bao-gia/QuotationRecordPage'),
  'QuotationRecordPage',
);
const OpportunityRecordPage = lazyScreen(
  () => import('../pages/co-hoi/OpportunityRecordPage'),
  'OpportunityRecordPage',
);
const UserListPage = lazyScreen(() => import('../pages/nguoi-dung/UserListPage'), 'UserListPage');
const UserRecordPage = lazyScreen(
  () => import('../pages/nguoi-dung/UserRecordPage'),
  'UserRecordPage',
);
const TestListPage = lazyScreen(() => import('../pages/phieu/TestListPage'), 'TestListPage');
const TestRecordPage = lazyScreen(() => import('../pages/phieu/TestRecordPage'), 'TestRecordPage');
const AppointmentListPage = lazyScreen(
  () => import('../pages/lich-hen/AppointmentListPage'),
  'AppointmentListPage',
);
const LeadRecordPage = lazyScreen(() => import('../pages/lead/LeadRecordPage'), 'LeadRecordPage');
const PortalTabPage = lazyScreen(() => import('../pages/common/PortalPages'), 'PortalTabPage');
const ProfilePage = lazyScreen(() => import('../pages/common/ProfilePage'), 'ProfilePage');
const HomePage = lazyScreen(() => import('../pages/HomePage'), 'HomePage');
const DetailDemoPage = lazyScreen(() => import('../pages/dev/DetailDemoPage'), 'DetailDemoPage');
const DialogsDemoPage = lazyScreen(() => import('../pages/dev/DialogsDemoPage'), 'DialogsDemoPage');
const ListDemoPage = lazyScreen(() => import('../pages/dev/ListDemoPage'), 'ListDemoPage');
const PatternPage = lazyScreen(() => import('../pages/dev/PatternPage'), 'PatternPage');

// Trang mẫu thành phần: chỉ có ở bản thử nghiệm, xem trước và local; bản chạy thật không có route này.
const SHOW_PATTERNS = parseAppEnv(import.meta.env.VITE_APP_ENV) !== 'production';

const GD3 = 'giai đoạn 3';
const GD4 = 'giai đoạn 4';

export const routes: RouteObject[] = [
  {
    path: '/',
    errorElement: <RouteErrorPage />,
    children: [
      { index: true, element: <RootRedirect /> },
      // Đăng nhập và các bước bắt buộc (khuôn K11).
      { path: 'dang-nhap', element: <LoginPage /> },
      { path: 'dang-nhap/hoc-sinh', element: <StudentLoginPage /> },
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
          { path: 'tai-khoan', element: <ProfilePage /> },
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
            path: 'don-hang',
            element: (
              <GatedCrmEntry slug="don-hang">
                <OrderListPage />
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
            path: 'quan-tri/nguoi-dung',
            element: (
              <GatedCrmEntry slug="quan-tri/nguoi-dung">
                <UserListPage />
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
          { index: true, element: <PortalTabPage title="Hôm nay" stage={GD3} /> },
          { path: 'lich-day', element: <PortalTabPage title="Lịch dạy" stage={GD3} /> },
          { path: 'lop', element: <PortalTabPage title="Lớp" stage={GD3} /> },
          { path: 'viec-can-lam', element: <PortalTabPage title="Việc cần làm" stage={GD3} /> },
          { path: 'tai-khoan', element: <ProfilePage /> },
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
          { index: true, element: <PortalTabPage title="Trang chủ" stage={GD4} /> },
          { path: 'bai-tap', element: <PortalTabPage title="Bài tập" stage={GD4} /> },
          { path: 'lich', element: <PortalTabPage title="Lịch" stage={GD4} /> },
          { path: 'ket-qua', element: <PortalTabPage title="Kết quả" stage={GD4} /> },
          { path: 'tai-khoan', element: <ProfilePage /> },
          { path: '*', element: <NotFoundView /> },
        ],
      },
      { path: '*', element: <NotFoundView /> },
    ],
  },
];
