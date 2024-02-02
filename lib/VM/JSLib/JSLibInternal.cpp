/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#include "JSLibInternal.h"

#include "hermes/Regex/Executor.h"
#include "hermes/Regex/Regex.h"
#include "hermes/Regex/RegexTraits.h"
#include "hermes/VM/PropertyAccessor.h"
#include "hermes/VM/Runtime.h"
#include "hermes/VM/StringBuilder.h"
#include "hermes/VM/StringPrimitive.h"
#include "hermes/VM/StringView.h"
#pragma GCC diagnostic push

#ifdef HERMES_COMPILER_SUPPORTS_WSHORTEN_64_TO_32
#pragma GCC diagnostic ignored "-Wshorten-64-to-32"
#endif
namespace hermes {
namespace vm {

Handle<NativeConstructor> defineSystemConstructor(
    Runtime &runtime,
    SymbolID name,
    NativeFunctionPtr nativeFunctionPtr,
    Handle<JSObject> prototypeObjectHandle,
    Handle<JSObject> constructorProtoObjectHandle,
    unsigned paramCount,
    NativeConstructor::CreatorFunction *creator,
    CellKind targetKind) {
  auto constructor = runtime.makeHandle(NativeConstructor::create(
      runtime,
      constructorProtoObjectHandle,
      nullptr,
      nativeFunctionPtr,
      paramCount,
      creator,
      targetKind));

  auto st = Callable::defineNameLengthAndPrototype(
      constructor,
      runtime,
      name,
      paramCount,
      prototypeObjectHandle,
      Callable::WritablePrototype::No,
      false);
  (void)st;
  assert(
      st != ExecutionStatus::EXCEPTION && "defineLengthAndPrototype() failed");

  // Define the global.
  DefinePropertyFlags dpf = DefinePropertyFlags::getNewNonEnumerableFlags();

  auto res = JSObject::defineOwnProperty(
      runtime.getGlobal(), runtime, name, dpf, constructor);
  assert(
      res != ExecutionStatus::EXCEPTION && *res &&
      "defineOwnProperty() failed");
  (void)res;

  return constructor;
}

CallResult<HermesValue> defineMethod(
    Runtime &runtime,
    Handle<JSObject> objectHandle,
    SymbolID propertyName,
    SymbolID methodName,
    void *context,
    NativeFunctionPtr nativeFunctionPtr,
    unsigned paramCount,
    DefinePropertyFlags dpf) {
  GCScope gcScope{runtime};

  auto method = NativeFunction::create(
      runtime,
      Handle<JSObject>::vmcast(&runtime.functionPrototype),
      context,
      nativeFunctionPtr,
      methodName,
      paramCount,
      Runtime::makeNullHandle<JSObject>());

  auto res = JSObject::defineOwnProperty(
      objectHandle, runtime, propertyName, dpf, method);
  (void)res;
  assert(
      res != ExecutionStatus::EXCEPTION && *res &&
      "defineOwnProperty() failed");

  return method.getHermesValue();
}

Handle<NativeConstructor> defineSystemConstructor(
    Runtime &runtime,
    SymbolID name,
    NativeFunctionPtr nativeFunctionPtr,
    Handle<JSObject> prototypeObjectHandle,
    unsigned paramCount,
    NativeConstructor::CreatorFunction *creator,
    CellKind targetKind) {
  return defineSystemConstructor(
      runtime,
      name,
      nativeFunctionPtr,
      prototypeObjectHandle,
      Handle<JSObject>::vmcast(&runtime.functionPrototype),
      paramCount,
      creator,
      targetKind);
}

void defineMethod(
    Runtime &runtime,
    Handle<JSObject> objectHandle,
    SymbolID name,
    void *context,
    NativeFunctionPtr nativeFunctionPtr,
    unsigned paramCount) {
  DefinePropertyFlags dpf = DefinePropertyFlags::getNewNonEnumerableFlags();
  (void)defineMethod(
      runtime, objectHandle, name, context, nativeFunctionPtr, paramCount, dpf);
}

void defineAccessor(
    Runtime &runtime,
    Handle<JSObject> objectHandle,
    SymbolID propertyName,
    SymbolID methodName,
    void *context,
    NativeFunctionPtr getterFunc,
    NativeFunctionPtr setterFunc,
    bool enumerable,
    bool configurable) {
  assert(
      (getterFunc || setterFunc) &&
      "at least a getter or a setter must be specified");
  ExecutionStatus status{};
  (void)status;

  GCScope gcScope{runtime};

  StringView nameView =
      runtime.getIdentifierTable().getStringView(runtime, methodName);
  assert(nameView.isASCII() && "Only ASCII accessors are supported");

  MutableHandle<NativeFunction> getter{runtime};
  if (getterFunc) {
    // Set the name by prepending "get ".
    llvh::SmallString<32> getterName{"get "};
    llvh::raw_svector_ostream os{getterName};
    os << nameView;

    auto strRes = runtime.ignoreAllocationFailure(
        StringPrimitive::create(runtime, getterName));
    SymbolID getterFuncName =
        runtime
            .ignoreAllocationFailure(
                runtime.getIdentifierTable().getSymbolHandleFromPrimitive(
                    runtime,
                    createPseudoHandle(vmcast<StringPrimitive>(strRes))))
            .get();

    auto funcRes = NativeFunction::create(
        runtime,
        Handle<JSObject>::vmcast(&runtime.functionPrototype),
        context,
        getterFunc,
        getterFuncName,
        0,
        Runtime::makeNullHandle<JSObject>());
    getter = funcRes.get();
  }

  MutableHandle<NativeFunction> setter{runtime};
  if (setterFunc) {
    // Set the name by prepending "set ".
    llvh::SmallString<32> setterName{"set "};
    llvh::raw_svector_ostream os{setterName};
    os << nameView;

    auto strRes = runtime.ignoreAllocationFailure(
        StringPrimitive::create(runtime, setterName));
    SymbolID setterFuncName =
        runtime
            .ignoreAllocationFailure(
                runtime.getIdentifierTable().getSymbolHandleFromPrimitive(
                    runtime,
                    createPseudoHandle(vmcast<StringPrimitive>(strRes))))
            .get();

    auto funcRes = NativeFunction::create(
        runtime,
        Handle<JSObject>::vmcast(&runtime.functionPrototype),
        context,
        setterFunc,
        setterFuncName,
        1,
        Runtime::makeNullHandle<JSObject>());
    setter = funcRes.get();
  }

  auto accessor = runtime.makeHandle<PropertyAccessor>(
      PropertyAccessor::create(runtime, getter, setter));

  DefinePropertyFlags dpf{};
  dpf.setEnumerable = 1;
  dpf.setConfigurable = 1;
  dpf.setGetter = 1;
  dpf.setSetter = 1;
  dpf.enumerable = enumerable;
  dpf.configurable = configurable;

  auto res = JSObject::defineOwnProperty(
      objectHandle, runtime, propertyName, dpf, accessor);
  (void)res;
  assert(
      res != ExecutionStatus::EXCEPTION && *res &&
      "defineOwnProperty() failed");
}

void defineProperty(
    Runtime &runtime,
    Handle<JSObject> objectHandle,
    SymbolID name,
    Handle<> value,
    DefinePropertyFlags dpf) {
  auto res = JSObject::defineOwnProperty(
      objectHandle, runtime, name, dpf, value, PropOpFlags());
  (void)res;
  assert(
      res != ExecutionStatus::EXCEPTION && *res &&
      "defineOwnProperty() failed");
}

void defineProperty(
    Runtime &runtime,
    Handle<JSObject> objectHandle,
    SymbolID name,
    Handle<> value) {
  DefinePropertyFlags dpf = DefinePropertyFlags::getNewNonEnumerableFlags();

  return defineProperty(runtime, objectHandle, name, value, dpf);
}

ExecutionStatus iteratorCloseAndRethrow(
    Runtime &runtime,
    Handle<JSObject> iterator) {
  auto completion = runtime.makeHandle(runtime.getThrownValue());
  if (isUncatchableError(completion.getHermesValue())) {
    // If an uncatchable exception was raised, do not swallow it, but instead
    // propagate it.
    return ExecutionStatus::EXCEPTION;
  }
  runtime.clearThrownValue();
  auto status = iteratorClose(runtime, iterator, completion);
  (void)status;
  assert(
      status == ExecutionStatus::EXCEPTION && "exception swallowed mistakenly");
  return ExecutionStatus::EXCEPTION;
}

static std::vector<uint8_t> getReturnThisRegexBytecode() {
  const char16_t *returnThisRE = uR"X(^\s*return[ \t]+this\s*;?\s*$)X";
  return regex::Regex<regex::UTF16RegexTraits>(returnThisRE).compile();
}

static bool isReturnThis(Handle<StringPrimitive> str, Runtime &runtime) {
  // Fast check for minimal version.
  {
    auto minimal = runtime.getPredefinedString(Predefined::returnThis);
    if (str->equals(minimal)) {
      return true;
    }
  }
  // Regex match for variants.
  auto input = StringPrimitive::createStringView(runtime, str);
  static auto bytecode = getReturnThisRegexBytecode();
  auto result = regex::MatchRuntimeResult::NoMatch;
  if (input.isASCII()) {
    const char *begin = input.castToCharPtr();
    result = regex::searchWithBytecode(
        bytecode,
        begin,
        0,
        input.length(),
        nullptr,
        regex::constants::matchDefault | regex::constants::matchInputAllAscii,
        runtime.getOverflowGuardForRegex());
  } else {
    const char16_t *begin = input.castToChar16Ptr();
    result = regex::searchWithBytecode(
        bytecode,
        begin,
        0,
        input.length(),
        nullptr,
        regex::constants::matchDefault,
        runtime.getOverflowGuardForRegex());
  }
  return result == regex::MatchRuntimeResult::Match;
}

CallResult<HermesValue> createDynamicFunction(
    Runtime &runtime,
    NativeArgs args,
    DynamicFunctionKind kind) {
  return runtime.raiseSyntaxError("function constructor disabled in Hermes due to security reasons");
}

} // namespace vm
} // namespace hermes
