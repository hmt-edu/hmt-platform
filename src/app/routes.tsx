import type { RouteObject } from 'react-router';
import { RootLayout } from './RootLayout';
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
      { path: 'crm', element: <CrmPage /> },
      { path: 'gv', element: <GvPage /> },
      { path: 'hoc', element: <HocPage /> },
      { path: '*', element: <NotFoundPage /> },
    ],
  },
];
