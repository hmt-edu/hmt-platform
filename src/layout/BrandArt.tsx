// Hình minh hoạ của cột giới thiệu trang đăng nhập (thiết kế P1 v4, DN01): mạng nút nối nhau, ký hiệu toán và
// robot thầy giáo. Mã SVG lấy từ gói thiết kế. Bản này đứng yên; chuyển động (PR 5c) thêm bằng CSS ở `index.css`.

export function BrandArt() {
  return (
    <svg
      className="auth-art"
      viewBox="0 0 640 1000"
      preserveAspectRatio="xMidYMid slice"
      aria-hidden="true"
    >
      <g transform="translate(0,40)">
        <line className="auth-ln" x1="80" y1="760" x2="210" y2="690" />
        <line className="auth-ln" x1="210" y1="690" x2="330" y2="800" />
        <line className="auth-ln" x1="330" y1="800" x2="470" y2="720" />
        <line className="auth-ln" x1="470" y1="720" x2="560" y2="820" />
        <line className="auth-ln" x1="80" y1="760" x2="150" y2="880" />
        <line className="auth-ln" x1="150" y1="880" x2="300" y2="920" />
        <line className="auth-ln" x1="300" y1="920" x2="450" y2="900" />
        <line className="auth-ln" x1="450" y1="900" x2="560" y2="820" />
        <line className="auth-ln" x1="210" y1="690" x2="150" y2="880" />
        <line className="auth-ln" x1="330" y1="800" x2="300" y2="920" />
        <line className="auth-ln" x1="470" y1="720" x2="450" y2="900" />
        <line className="auth-ln" x1="210" y1="690" x2="120" y2="640" />
        <line className="auth-ln" x1="120" y1="640" x2="260" y2="600" />
        <line className="auth-ln" x1="260" y1="600" x2="400" y2="590" />
        <line className="auth-ln" x1="400" y1="590" x2="540" y2="640" />
        <line className="auth-ln" x1="540" y1="640" x2="470" y2="720" />
        <line className="auth-ln" x1="260" y1="600" x2="210" y2="690" />
        <line className="auth-ln" x1="400" y1="590" x2="470" y2="720" />
        <circle className="auth-nd" cx="80" cy="760" r="4" />
        <circle className="auth-nd" cx="210" cy="690" r="4" />
        <circle className="auth-nd" cx="330" cy="800" r="4" />
        <circle className="auth-nd" cx="470" cy="720" r="4" />
        <circle className="auth-nd" cx="560" cy="820" r="4" />
        <circle className="auth-nd" cx="150" cy="880" r="4" />
        <circle className="auth-nd" cx="300" cy="920" r="4" />
        <circle className="auth-nd" cx="450" cy="900" r="4" />
        <circle className="auth-nd" cx="540" cy="640" r="4" />
        <circle className="auth-nd" cx="400" cy="590" r="4" />
        <circle className="auth-nd" cx="260" cy="600" r="4" />
        <circle className="auth-nd" cx="120" cy="640" r="4" />
      </g>
      <text className="auth-sy" x="70" y="700" fontSize="44">
        π
      </text>
      <text className="auth-sy" x="520" y="640" fontSize="52">
        ∑
      </text>
      <text className="auth-sy" x="430" y="780" fontSize="34">
        √x
      </text>
      <text className="auth-sy" x="100" y="860" fontSize="56">
        ∫
      </text>
      <text className="auth-sy" x="300" y="620" fontSize="34">
        x²
      </text>
      <text className="auth-sy" x="400" y="880" fontSize="28">
        f(x)
      </text>
      <text className="auth-sy" x="200" y="780" fontSize="40">
        Δ
      </text>
      <text className="auth-sy" x="150" y="600" fontSize="40">
        ∞
      </text>
      <text className="auth-sy" x="260" y="900" fontSize="30">
        %
      </text>
    </svg>
  );
}

export function BrandRobot() {
  return (
    <svg className="auth-robot" viewBox="0 0 170 190" aria-hidden="true">
      <g className="auth-bob">
        <g className="auth-bub" transform="translate(-6,-10)">
          <rect x="0" y="0" width="82" height="26" rx="13" fill="#FFFFFF" />
          <path d="M52 24 L62 36 L40 25Z" fill="#FFFFFF" />
          <text
            x="41"
            y="17.5"
            fontSize="12"
            fontWeight="700"
            fill="#AB420F"
            fontFamily="Be Vietnam Pro, Inter, sans-serif"
            textAnchor="middle"
          >
            Xin chào!
          </text>
        </g>
        <rect x="96" y="64" width="68" height="54" rx="8" fill="#FFFFFF" />
        <rect x="101" y="69" width="58" height="44" rx="5" fill="#FFF4ED" />
        <text
          x="108"
          y="97"
          fontSize="14"
          fontWeight="700"
          fill="#CB4D0E"
          fontFamily="Be Vietnam Pro, Inter, sans-serif"
        >
          2+3=
        </text>
        <text
          className="auth-q1"
          x="145"
          y="97"
          fontSize="17"
          fontWeight="700"
          fill="#AB420F"
          fontFamily="Be Vietnam Pro, Inter, sans-serif"
        >
          ?
        </text>
        <text
          className="auth-q2"
          x="145"
          y="97"
          fontSize="17"
          fontWeight="700"
          fill="#1F7A3E"
          fontFamily="Be Vietnam Pro, Inter, sans-serif"
        >
          5
        </text>
        <path
          d="M104 118 L96 170 M156 118 L164 170"
          stroke="#FFFFFF"
          strokeWidth="4"
          strokeLinecap="round"
        />
        <rect x="108" y="114" width="46" height="5" rx="2.5" fill="#FDC6A6" />
        <line
          x1="62"
          y1="22"
          x2="62"
          y2="40"
          stroke="#FFFFFF"
          strokeWidth="3"
          strokeLinecap="round"
        />
        <circle className="auth-ant" cx="62" cy="19" r="5.5" fill="#FDC6A6" />
        <rect x="24" y="56" width="8" height="18" rx="4" fill="#FFFFFF" />
        <rect x="92" y="56" width="8" height="18" rx="4" fill="#FFFFFF" />
        <rect x="30" y="38" width="64" height="52" rx="18" fill="#FFFFFF" />
        <rect x="38" y="47" width="48" height="34" rx="12" fill="#FFE4D3" />
        <circle cx="52" cy="62" r="6.5" fill="#CB4D0E" />
        <circle cx="72" cy="62" r="6.5" fill="#CB4D0E" />
        <circle cx="54.5" cy="63.5" r="2.4" fill="#FFFFFF" />
        <circle cx="74.5" cy="63.5" r="2.4" fill="#FFFFFF" />
        <path
          d="M46 52 Q52 49 58 52"
          stroke="#8C3510"
          strokeWidth="2"
          fill="none"
          strokeLinecap="round"
        />
        <path
          d="M66 50 Q72 48 78 52"
          stroke="#8C3510"
          strokeWidth="2"
          fill="none"
          strokeLinecap="round"
        />
        <circle cx="45" cy="73" r="3.2" fill="#FDC6A6" />
        <circle cx="79" cy="73" r="3.2" fill="#FDC6A6" />
        <path
          d="M57 74 Q62 78 67 74"
          stroke="#CB4D0E"
          strokeWidth="2.4"
          fill="none"
          strokeLinecap="round"
        />
        <rect x="36" y="94" width="52" height="46" rx="16" fill="#FFFFFF" />
        <rect x="48" y="104" width="28" height="18" rx="6" fill="#FFE4D3" />
        <text
          x="62"
          y="118"
          fontSize="14"
          fontWeight="700"
          fill="#CB4D0E"
          textAnchor="middle"
          fontFamily="Be Vietnam Pro, Inter, sans-serif"
        >
          π
        </text>
        <rect
          x="22"
          y="100"
          width="12"
          height="30"
          rx="6"
          fill="#FFFFFF"
          transform="rotate(8 28 102)"
        />
        <g className="auth-pen">
          <path d="M84 106 L102 92" stroke="#FFFFFF" strokeWidth="12" strokeLinecap="round" />
          <circle cx="104" cy="90" r="6.5" fill="#FFFFFF" />
          <g transform="rotate(-35 104 90)">
            <rect x="103" y="76" width="4.4" height="20" rx="1.6" fill="#FDC6A6" />
            <path d="M103 76 L105.2 69 L107.4 76Z" fill="#8C3510" />
          </g>
        </g>
        <rect x="42" y="142" width="14" height="16" rx="6" fill="#FFFFFF" />
        <rect x="68" y="142" width="14" height="16" rx="6" fill="#FFFFFF" />
      </g>
    </svg>
  );
}
