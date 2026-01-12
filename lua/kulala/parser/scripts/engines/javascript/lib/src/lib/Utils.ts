const EMPTY_LENGTH = 0;
const ONE = 1;
const ZERO_INDEX = 0;

/**
 * Gets the value from an object based on a dot-separated path.
 * @param obj - The object to retrieve the value from.
 * @param path - The dot-separated path string (e.g., "a.b.c").
 * @returns The value at the specified path, or undefined if the path does not exist.
 * @example
 * const obj = { a: { b: { c: 42 } } };
 * const value = getObjectValueByPath(obj, "a.b.c");
 * console.log(value); // Output: 42
 * const missingValue = getObjectValueByPath(obj, "a.b.x");
 * console.log(missingValue); // Output: undefined
 */
export const getObjectValueByPath = function (
  obj: Record<string, unknown>,
  path: string,
): unknown {
  if (typeof path !== "string" || path.length === EMPTY_LENGTH) {
    return undefined;
  }
  const pathParts = path.split(".");
  let current: unknown = obj;
  for (const part of pathParts) {
    if (
      current !== undefined && current !== null &&
      typeof current === "object" && part in current
    ) {
      current = (current as Record<string, unknown>)[part];
    } else {
      return undefined;
    }
  }
  return current;
};

/**
 * Sets the value of a nested object property based on a dot-separated path.
 * If the path does not exist, it creates the necessary nested objects.
 * @param currentObj - The original object to modify.
 * @param path - The dot-separated path string (e.g., "a.b.c").
 * @param value - The value to set at the specified path.
 * @returns A new object with the updated value at the specified path.
 * @example
 * const obj = { a: { b: { c: 42 } } };
 * const newObj = setObjectValueByPath(obj, "a.b.c", 100);
 * console.log(newObj); // Output: { a: { b: { c: 100 } } }
 * const newObj2 = setObjectValueByPath(obj, "a.b.d", 200);
 * console.log(newObj2); // Output: { a: { b: { c: 42, d: 200 } } }
 * const newObj3 = setObjectValueByPath(obj, "a.x.y", 300);
 * console.log(newObj3); // Output: { a: { b: { c: 42 }, x: { y: 300 } } }
 */
export const setObjectValueByPath = function (
  currentObj: Record<string, unknown>,
  path: string,
  value: Record<string, unknown> | string | number | boolean | null,
): Record<string, unknown> {
  if (typeof path !== "string" || path.length === EMPTY_LENGTH) {
    return currentObj;
  }
  const pathParts = path.split(".");
  const newObj: Record<string, unknown> = { ...currentObj };
  let tempObj: Record<string, unknown> = newObj;
  for (let i = ZERO_INDEX; i < pathParts.length; i++) {
    const part = pathParts[i];
    if (i === pathParts.length - ONE) {
      tempObj[part] = value;
    } else {
      if (
        !(part in tempObj) || typeof tempObj[part] !== "object" ||
        tempObj[part] === null
      ) {
        tempObj[part] = {};
      }
      tempObj = tempObj[part] as Record<string, unknown>;
    }
  }
  return newObj;
};
