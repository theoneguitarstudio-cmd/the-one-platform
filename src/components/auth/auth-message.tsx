const MESSAGES: Record<string, string> = {
  auth_callback_failed: "驗證連結無效或已過期，請重新登入。",
  check_email: "若帳號資料有效，我們已寄出後續操作郵件。",
  expired_link: "連結無效或已過期，請重新取得連結。",
  invalid_credentials: "Email 或密碼不正確。",
  invalid_input: "請確認輸入資料格式。",
  invalid_password: "密碼至少 12 字元，並包含英文字母與數字。",
  password_updated: "密碼已更新，請重新登入。",
  reset_failed: "目前無法更新密碼，請重新取得重設連結。",
  signed_out: "你已安全登出。",
  signup_failed: "目前無法建立帳號，請稍後再試。",
};

type AuthMessageProps = {
  code?: string;
};

export function AuthMessage({ code }: AuthMessageProps) {
  if (!code || !MESSAGES[code]) {
    return null;
  }

  return (
    <p
      className="rounded-lg border border-[var(--border)] bg-[var(--surface)] px-4 py-3 text-sm text-[var(--text-secondary)]"
      role="status"
    >
      {MESSAGES[code]}
    </p>
  );
}
