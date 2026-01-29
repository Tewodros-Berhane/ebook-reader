export function isValidCfi(value: string): boolean {
  return value.startsWith("epubcfi(") && value.endsWith(")");
}

export function normalizeCfi(value: string): string {
  return value.trim();
}
