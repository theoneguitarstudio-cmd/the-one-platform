export function GuitarArt({ compact = false }: { compact?: boolean }) {
  return <div className={"guitar-art" + (compact ? " compact" : "")} role="img" aria-label="暖木色吉他與柔和光暈的原創插畫"><div className="art-orbit orbit-one" /><div className="art-orbit orbit-two" /><div className="art-grain" /><svg viewBox="0 0 440 520" aria-hidden="true">
    <g transform="rotate(22 220 260)">
      <ellipse cx="236" cy="447" rx="105" ry="24" fill="#554130" opacity=".1"/>
      <path d="M186 220 C134 183 97 236 135 277 C143 289 135 302 110 326 C67 367 83 451 158 475 C242 501 312 445 301 383 C296 353 274 328 253 300 C232 272 272 238 247 214 C230 197 209 205 199 222Z" fill="#b47c51"/>
      <path d="M186 216 C138 187 106 237 141 277 C153 295 139 310 117 333 C80 375 96 443 162 464 C236 488 297 440 291 385 C289 355 266 328 246 301 C227 273 262 238 241 221 C226 207 209 216 199 231Z" fill="#e4b985" stroke="#f8ddab" strokeWidth="4"/>
      <path d="M115 367 Q190 336 287 388 M111 377 Q201 352 290 398 M116 396 Q190 368 288 412 M133 433 Q211 400 268 439" fill="none" stroke="#b47c51" opacity=".22"/>
      <circle cx="200" cy="312" r="40" fill="#ca965c" stroke="#7f5339" strokeWidth="2"/><circle cx="200" cy="312" r="32" fill="#392e2d"/><circle cx="200" cy="312" r="27" fill="#201f26"/>
      <path d="M229 309 Q258 322 268 359 L235 365Z" fill="#8b4a3c" opacity=".8"/>
      <path d="M180 58 L211 58 L217 285 L184 285Z" fill="#584236" stroke="#d5b18b" strokeWidth="3"/>
      {[90,113,137,161,185,205,224,242,259,275].map(y=><path key={y} d={"M182 "+y+"h32"} stroke="#c8b9a2" strokeWidth="2"/>)}
      <path d="M173 16 Q195 7 216 17 L217 67 L176 67Z" fill="#ba855d" stroke="#e0b891" strokeWidth="3"/>
      {[28,44,60].map(y=><g key={y}><rect x="167" y={y} width="10" height="6" rx="3" fill="#b6afaa"/><rect x="215" y={y} width="10" height="6" rx="3" fill="#b6afaa"/></g>)}
      <rect x="169" y="386" width="67" height="16" rx="4" fill="#594136"/><path d="M180 389h46" stroke="#eee0bd" strokeWidth="3"/>
      {[184,190,196,202,208,214].map((x,i)=><path key={x} d={"M"+x+" 25 L"+(180+i*8)+" 391"} fill="none" stroke="#fff4d2" opacity=".7" strokeWidth={.6+i*.12}/>)}
    </g></svg><span className="art-caption">FIND YOUR OWN RHYTHM</span></div>;
}
