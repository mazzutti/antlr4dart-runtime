part of antlr4dart;

/**
 * Returns the qualified name of [t].
 */
Symbol getTypeName(Type t) => reflectClass(t).qualifiedName;

/**
 * Returns true if [o] implements [type].
 */
bool implements(Object o, Type type) =>
    classImplements(reflect(o).type, getTypeName(type));

/**
 * Returns true if [m], its superclasses or interfaces have the qualified name
 * [name].
 */
bool classImplements(ClassMirror m, Symbol name) {
  if (m == null) return false;
  if (m.qualifiedName == name) return true;
  if (m.qualifiedName == const Symbol('dart.core.Object')) return false;
  if (classImplements(m.superclass, name)) return true;
  if (m.superinterfaces.any((i) => classImplements(i, name))) return true;
  return false;
}
