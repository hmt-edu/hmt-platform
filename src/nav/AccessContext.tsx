import { createContext, useContext, useMemo, useState, type ReactNode } from 'react';
import { useAuth } from '../lib/auth/authContext';
import { Spinner, StateView } from '../ui/Feedback';
import { Button } from '../ui/Button';
import { ALL_BRANCHES, buildAccess, type AccessView } from './access';
import { useAccessData } from './accessData';

type AccessContextValue = AccessView & {
  selectedBranch: string;
  setSelectedBranch: (value: string) => void;
};

const AccessContext = createContext<AccessContextValue | null>(null);
const STORAGE_KEY = 'hmt:co-so-dang-xem';

function readStored(): string {
  try {
    return sessionStorage.getItem(STORAGE_KEY) ?? ALL_BRANCHES;
  } catch {
    return ALL_BRANCHES;
  }
}

/** Tải quyền, cơ sở, công tắc một lần cho cả khung; con cháu đọc qua useAccess(). */
export function AccessProvider({ children }: { children: ReactNode }) {
  const { claims } = useAuth();
  const query = useAccessData();
  const [selectedBranch, setSelected] = useState(readStored);

  const value = useMemo<AccessContextValue | null>(() => {
    if (!query.data || !claims) return null;
    const stillValid =
      selectedBranch === ALL_BRANCHES ||
      query.data.branches.some((b) => b.id === selectedBranch && !b.is_office);
    const branch = stillValid ? selectedBranch : ALL_BRANCHES;
    return {
      ...buildAccess(query.data, claims, branch),
      selectedBranch: branch,
      setSelectedBranch: (next) => {
        setSelected(next);
        try {
          sessionStorage.setItem(STORAGE_KEY, next);
        } catch {
          // Trình duyệt chặn lưu trữ: chỉ nhớ trong trang đang mở.
        }
      },
    };
  }, [query.data, claims, selectedBranch]);

  if (query.isPending) return <Spinner label="Đang tải quyền của bạn…" />;
  if (query.isError || !value) {
    return (
      <StateView
        kind="error"
        title="Không tải được trang"
        actions={<Button onClick={() => void query.refetch()}>Thử lại</Button>}
      >
        Kiểm tra mạng rồi bấm Thử lại. Nếu vẫn lỗi, báo quản trị viên.
      </StateView>
    );
  }
  return <AccessContext.Provider value={value}>{children}</AccessContext.Provider>;
}

// eslint-disable-next-line react-refresh/only-export-components -- hook đi cùng provider
export function useAccess(): AccessContextValue {
  const value = useContext(AccessContext);
  if (!value) throw new Error('useAccess phải nằm trong AccessProvider');
  return value;
}
