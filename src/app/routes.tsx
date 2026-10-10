import type { RouteObject } from 'react-router';
import { RequirePortal } from './RequirePortal';
import { RootLayout } from './RootLayout';
import { ChangePasswordPage } from '../pages/ChangePasswordPage';
import { LoginPage } from '../pages/LoginPage';
import { MfaPage } from '../pages/MfaPage';
import { CrmPage } from '../pages/CrmPage';
import { GvPage } from '../pages/GvPage';
import { HocPage } from '../pages/HocPage';
import { HomePage } from '../pages/HomePage';
import { NotFoundPage } from '../pages/NotFoundPage';

export const routes: RouteObject[] = [
  {
    path: '/',
    element: <RootLayout />,
    children: [
      { index: true, element: <HomePage /> },
      { path: 'dang-nhap', element: <LoginPage /> },
      { path: 'doi-mat-khau', element: <ChangePasswordPage /> },
      { path: 'xac-thuc-hai-buoc', element: <MfaPage /> },
      {
        path: 'crm',
        element: (
          <RequirePortal portal="crm">
            <CrmPage />
          </RequirePortal>
        ),
      },
      {
        path: 'gv',
        element: (
          <RequirePortal portal="gv">
            <GvPage />
          </RequirePortal>
        ),
      },
      {
        path: 'hoc',
        element: (
          <RequirePortal portal="hoc">
            <HocPage />
          </RequirePortal>
        ),
      },
      { path: '*', element: <NotFoundPage /> },
    ],
  },
];
