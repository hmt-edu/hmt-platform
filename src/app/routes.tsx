import type { RouteObject } from 'react-router';
import { CrmShell } from '../layout/CrmShell';
import { StudentShell, TeacherShell } from '../layout/TabShell';
import { LoginPage, StudentLoginPage } from '../pages/auth/LoginPages';
import { MfaSetupPage, MfaVerifyPage } from '../pages/auth/MfaPages';
import {
  CannotLoginPage,
  ChangePasswordPage,
  ForgotPasswordPage,
  ResetPasswordPage,
} from '../pages/auth/PasswordPages';
import { ChoosePortalPage } from '../pages/common/ChoosePortalPage';
import { CrmHomePage, CrmSectionPage, PortalTabPage } from '../pages/common/PortalPages';
import { ProfilePage } from '../pages/common/ProfilePage';
import { NotFoundView, RouteErrorPage } from '../pages/common/StatePages';
import { HomePage } from '../pages/HomePage';
import { parseAppEnv } from '../lib/env';
import { DetailDemoPage } from '../pages/dev/DetailDemoPage';
import { DialogsDemoPage } from '../pages/dev/DialogsDemoPage';
import { ListDemoPage } from '../pages/dev/ListDemoPage';
import { PatternPage } from '../pages/dev/PatternPage';
import { NoPortalPage, RequirePortal, RootRedirect } from './guards';

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
          { index: true, element: <CrmHomePage /> },
          { path: 'tai-khoan', element: <ProfilePage /> },
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
