export type NativeRouteParam = string | string[] | undefined;

export function parsePositiveIdParam(value: NativeRouteParam): number | undefined {
  if (typeof value !== "string") return undefined;
  const parsed = Number(value);
  return Number.isInteger(parsed) && parsed > 0 ? parsed : undefined;
}

export function hasInvalidIdParam(value: NativeRouteParam): boolean {
  return value !== undefined && parsePositiveIdParam(value) === undefined;
}
