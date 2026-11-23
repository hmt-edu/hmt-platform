// Hình minh hoạ của cột giới thiệu trang đăng nhập (thiết kế P1 v4, DN01): mạng nút nối nhau, ký hiệu toán và
// cột tiến bộ. Mã SVG lấy từ gói thiết kế; chuyển động bằng CSS ở `index.css` (tắt khi người dùng bật giảm chuyển động).

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

/** Năm cột bo tròn tăng dần (năm cơ sở, tiến bộ), cột cao nhất cắm cờ, hai ngôi sao lấp lánh (canvas 9933 v149). Chuyển động ở `index.css`. */
export function BrandBars() {
  return (
    <svg className="auth-bars" viewBox="0 0 320 250" aria-hidden="true">
      <g className="auth-rise">
        <rect x="14" y="170" width="46" height="60" rx="12" fill="#fff" fillOpacity=".2" />
      </g>
      <g className="auth-rise" style={{ animationDelay: '.2s' }}>
        <rect x="70" y="140" width="46" height="90" rx="12" fill="#fff" fillOpacity=".34" />
      </g>
      <g className="auth-rise" style={{ animationDelay: '.4s' }}>
        <rect x="126" y="108" width="46" height="122" rx="12" fill="#fff" fillOpacity=".52" />
      </g>
      <g className="auth-rise" style={{ animationDelay: '.6s' }}>
        <rect x="182" y="74" width="46" height="156" rx="12" fill="#fff" fillOpacity=".74" />
      </g>
      <g className="auth-rise" style={{ animationDelay: '.8s' }}>
        <rect x="238" y="40" width="46" height="190" rx="12" fill="#fff" />
      </g>
      <g className="auth-flag">
        <line
          x1="261"
          y1="40"
          x2="261"
          y2="6"
          stroke="#fff"
          strokeWidth="4"
          strokeLinecap="round"
        />
        <path d="M263 7 L292 17 L263 28Z" fill="#FFD3B5" />
      </g>
      <g className="auth-spk">
        <path d="M30 120 l4 10 10 4 -10 4 -4 10 -4 -10 -10 -4 10 -4z" fill="#fff" />
      </g>
      <g className="auth-spk" style={{ animationDelay: '1.2s' }}>
        <path d="M190 36 l3 7 7 3 -7 3 -3 7 -3 -7 -7 -3 7 -3z" fill="#fff" />
      </g>
    </svg>
  );
}

const SLOGAN_WORDS = [
  'HỌC',
  'TẬP',
  '=',
  'NIỀM',
  'VUI,',
  'TIẾN',
  'BỘ',
  '=',
  'NĂNG',
  'LỰC,',
  'CHINH',
  'PHỤC',
  '∀',
  'CUỘC',
  'THI',
];
const SLOGAN_FULL = 'Học tập bằng niềm vui, tiến bộ bằng năng lực, chinh phục mọi cuộc thi';
const SLOGAN_STEP_SECONDS = 0.42; // allow-number: nhịp sáng từng từ theo canvas, không phải số nghiệp vụ

/** Slogan đáy cột: từng từ sáng lần lượt (tắt khi giảm chuyển động); nhãn đọc màn hình là câu đầy đủ, các từ ẩn với trình đọc. */
export function BrandSlogan() {
  return (
    <p className="auth-slogan" role="img" aria-label={SLOGAN_FULL}>
      {SLOGAN_WORDS.map((w, i) => (
        <span
          key={i}
          className={w === '=' || w === '∀' ? 'auth-w auth-w-sym' : 'auth-w'}
          style={{ animationDelay: `${(i * SLOGAN_STEP_SECONDS).toFixed(2)}s` }}
          aria-hidden="true"
        >
          {w}
        </span>
      ))}
    </p>
  );
}
