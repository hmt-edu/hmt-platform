// Tải sẵn phần sau đăng nhập trong lúc người dùng đang gõ email, mật khẩu (Chat 13:20, hiệu năng đăng nhập).
// Đo 18/11 (Playwright, 4G chậm, CPU chậm 4 lần): sau khi bấm Đăng nhập, gói khung CRM, trang chủ và các phông chữ đậm/vừa chỉ bắt đầu tải SAU khi
// dữ liệu phiên về, và 12 tệp phông tranh băng thông với lời gọi đăng nhập. Tải sẵn lúc rảnh ở trang đăng nhập bỏ được đoạn nối tiếp đó.
// Chỉ tải mã và phông (công khai, không dữ liệu người dùng); tôn trọng chế độ tiết kiệm dữ liệu của trình duyệt.

const FONTS = [
  '500 1em Inter',
  '600 1em Inter',
  '700 1em Inter',
  '600 1em "Be Vietnam Pro"',
  '700 1em "Be Vietnam Pro"',
];
// Mẫu chữ để trình duyệt chọn đúng các tệp phông con (latin, vietnamese) sẽ dùng khi hiện tiếng Việt.
const SAMPLE = 'AaĐđƠơƯưẠạẢảẤấẦầẨẩẪẫẬậ';

type NetworkInfo = { connection?: { saveData?: boolean } };

export function prefetchAfterLogin(): () => void {
  if ((navigator as unknown as NetworkInfo).connection?.saveData === true) return () => undefined;
  const run = () => {
    void import('../../layout/CrmShell');
    void import('../../pages/home/CrmHome');
    void import('../../layout/TabShell');
    for (const font of FONTS) void document.fonts?.load(font, SAMPLE).catch(() => undefined);
  };
  if (typeof window.requestIdleCallback === 'function') {
    const id = window.requestIdleCallback(run, { timeout: 3000 }); // allow-number: hạn chờ kỹ thuật của trình duyệt, không phải số nghiệp vụ
    return () => window.cancelIdleCallback(id);
  }
  const id = window.setTimeout(run, 1500); // allow-number: độ trễ kỹ thuật khi trình duyệt không có requestIdleCallback
  return () => window.clearTimeout(id);
}
