/** Nhãn cơ sở «CS5 Mỹ Đình» như các màn khác; chưa biết tên thì chỉ hiện mã. */
export function branchLabel(code: string, branches: { code: string; name: string }[]): string {
  const name = branches.find((b) => b.code === code)?.name;
  return name ? `${code} ${name}` : code;
}
