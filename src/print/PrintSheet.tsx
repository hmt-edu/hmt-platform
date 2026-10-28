// Khuôn K13 (bản in A4 dọc): dải cam, đầu trang logo chung HMT kèm tên và địa chỉ cơ sở (không in điện thoại cơ sở, không khẩu hiệu),
// tiêu đề và số bản ghi, hai khối thông tin, bảng dòng, tổng bằng số và bằng chữ, chỗ ký, chân trang. Chỉ dàn trang: mọi con số do nơi dùng đưa vào.
import type { ReactNode } from 'react';
import logo from '../../design/hmt-p0-p2/assets/Logo-HMT-cropped.svg';
import './print-sheet.css';

export type PrintSheetProps = {
  orgName: string;
  address: string | null;
  title: string;
  subtitle: string;
  /** Số bản ghi, kèm mã cũ nếu có. */
  code: string;
  legacyRef?: string | null | undefined;
  /** Nhãn đóng khung cạnh số (BẢN NHÁP, ĐÃ TỪ CHỐI, ĐÃ HUỶ); không có thì không hiện. */
  stamp?: string | null | undefined;
  /** Hai khối thông tin dưới tiêu đề. */
  boxes: ReactNode;
  /** Bảng dòng. */
  children: ReactNode;
  /** Chữ nhỏ dưới bảng. */
  note?: ReactNode;
  words: string;
  totals: ReactNode;
  signatures: ReactNode;
  printedOn: string;
};

export function PrintSheet(props: PrintSheetProps) {
  const { orgName, address, stamp, legacyRef } = props;
  return (
    <article className="k13-paper" aria-label={props.title}>
      <div className="k13-band" />
      <div className="k13-in">
        <header className="k13-h">
          <img className="k13-img" src={logo} alt="Hoà Ma Toán" />
          <div className="k13-org">
            <h2>{orgName}</h2>
            {address && <div>{address}</div>}
          </div>
        </header>
        <div className="k13-ttl">
          <div>
            <h1 className="k13-t">{props.title}</h1>
            <div className="k13-sub">{props.subtitle}</div>
          </div>
          <div className="k13-no">
            {stamp && <div className="k13-stamp">{stamp}</div>}
            <div>
              <span>Số</span>
              <b>{props.code}</b>
            </div>
            {legacyRef && <i>{`mã cũ ${legacyRef}`}</i>}
          </div>
        </div>
        <div className="k13-meta">{props.boxes}</div>
        {props.children}
        {props.note && <div className="k13-help2">{props.note}</div>}
        <div className="k13-bottom">
          <div className="k13-words">
            <span>Bằng chữ</span>
            {props.words}
          </div>
          <div className="k13-total">{props.totals}</div>
        </div>
        <div className="k13-sign">{props.signatures}</div>
      </div>
      <footer className="k13-foot">
        <span>{orgName}</span>
        <span>{`In ngày ${props.printedOn}`}</span>
      </footer>
    </article>
  );
}
