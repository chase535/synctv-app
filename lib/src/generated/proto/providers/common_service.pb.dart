// This is a generated file - do not edit.
//
// Generated from proto/providers/common_service.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import '../source_config.pbenum.dart' as $1;
import 'common.pb.dart' as $0;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

/// Browser cookies are accepted only when binding a provider session. The server
/// never includes this message in a list/binding response.
class WebSessionCookie extends $pb.GeneratedMessage {
  factory WebSessionCookie({
    $core.String? name,
    $core.String? value,
    $core.String? domain,
    $core.String? path,
    $core.bool? secure,
    $core.bool? httpOnly,
    $core.bool? sessionOnly,
    $fixnum.Int64? expiresAt,
  }) {
    final result = create();
    if (name != null) result.name = name;
    if (value != null) result.value = value;
    if (domain != null) result.domain = domain;
    if (path != null) result.path = path;
    if (secure != null) result.secure = secure;
    if (httpOnly != null) result.httpOnly = httpOnly;
    if (sessionOnly != null) result.sessionOnly = sessionOnly;
    if (expiresAt != null) result.expiresAt = expiresAt;
    return result;
  }

  WebSessionCookie._();

  factory WebSessionCookie.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory WebSessionCookie.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WebSessionCookie',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'synctv.provider.common'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aOS(2, _omitFieldNames ? '' : 'value')
    ..aOS(3, _omitFieldNames ? '' : 'domain')
    ..aOS(4, _omitFieldNames ? '' : 'path')
    ..aOB(5, _omitFieldNames ? '' : 'secure')
    ..aOB(6, _omitFieldNames ? '' : 'httpOnly')
    ..aOB(7, _omitFieldNames ? '' : 'sessionOnly')
    ..aInt64(8, _omitFieldNames ? '' : 'expiresAt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WebSessionCookie clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WebSessionCookie copyWith(void Function(WebSessionCookie) updates) =>
      super.copyWith((message) => updates(message as WebSessionCookie))
          as WebSessionCookie;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static WebSessionCookie create() => WebSessionCookie._();
  @$core.override
  WebSessionCookie createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static WebSessionCookie getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<WebSessionCookie>(create);
  static WebSessionCookie? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get value => $_getSZ(1);
  @$pb.TagNumber(2)
  set value($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasValue() => $_has(1);
  @$pb.TagNumber(2)
  void clearValue() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get domain => $_getSZ(2);
  @$pb.TagNumber(3)
  set domain($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDomain() => $_has(2);
  @$pb.TagNumber(3)
  void clearDomain() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get path => $_getSZ(3);
  @$pb.TagNumber(4)
  set path($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPath() => $_has(3);
  @$pb.TagNumber(4)
  void clearPath() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get secure => $_getBF(4);
  @$pb.TagNumber(5)
  set secure($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSecure() => $_has(4);
  @$pb.TagNumber(5)
  void clearSecure() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get httpOnly => $_getBF(5);
  @$pb.TagNumber(6)
  set httpOnly($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasHttpOnly() => $_has(5);
  @$pb.TagNumber(6)
  void clearHttpOnly() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.bool get sessionOnly => $_getBF(6);
  @$pb.TagNumber(7)
  set sessionOnly($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasSessionOnly() => $_has(6);
  @$pb.TagNumber(7)
  void clearSessionOnly() => $_clearField(7);

  @$pb.TagNumber(8)
  $fixnum.Int64 get expiresAt => $_getI64(7);
  @$pb.TagNumber(8)
  set expiresAt($fixnum.Int64 value) => $_setInt64(7, value);
  @$pb.TagNumber(8)
  $core.bool hasExpiresAt() => $_has(7);
  @$pb.TagNumber(8)
  void clearExpiresAt() => $_clearField(8);
}

class BindWebSessionRequest extends $pb.GeneratedMessage {
  factory BindWebSessionRequest({
    $1.SourceProvider? provider,
    $core.String? label,
    $core.Iterable<WebSessionCookie>? cookies,
  }) {
    final result = create();
    if (provider != null) result.provider = provider;
    if (label != null) result.label = label;
    if (cookies != null) result.cookies.addAll(cookies);
    return result;
  }

  BindWebSessionRequest._();

  factory BindWebSessionRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BindWebSessionRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BindWebSessionRequest',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'synctv.provider.common'),
      createEmptyInstance: create)
    ..aE<$1.SourceProvider>(1, _omitFieldNames ? '' : 'provider',
        enumValues: $1.SourceProvider.values)
    ..aOS(2, _omitFieldNames ? '' : 'label')
    ..pPM<WebSessionCookie>(3, _omitFieldNames ? '' : 'cookies',
        subBuilder: WebSessionCookie.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BindWebSessionRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BindWebSessionRequest copyWith(
          void Function(BindWebSessionRequest) updates) =>
      super.copyWith((message) => updates(message as BindWebSessionRequest))
          as BindWebSessionRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BindWebSessionRequest create() => BindWebSessionRequest._();
  @$core.override
  BindWebSessionRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BindWebSessionRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BindWebSessionRequest>(create);
  static BindWebSessionRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $1.SourceProvider get provider => $_getN(0);
  @$pb.TagNumber(1)
  set provider($1.SourceProvider value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasProvider() => $_has(0);
  @$pb.TagNumber(1)
  void clearProvider() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get label => $_getSZ(1);
  @$pb.TagNumber(2)
  set label($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLabel() => $_has(1);
  @$pb.TagNumber(2)
  void clearLabel() => $_clearField(2);

  @$pb.TagNumber(3)
  $pb.PbList<WebSessionCookie> get cookies => $_getList(2);
}

class BindWebSessionResponse extends $pb.GeneratedMessage {
  factory BindWebSessionResponse({
    WebSessionBinding? binding,
  }) {
    final result = create();
    if (binding != null) result.binding = binding;
    return result;
  }

  BindWebSessionResponse._();

  factory BindWebSessionResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BindWebSessionResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BindWebSessionResponse',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'synctv.provider.common'),
      createEmptyInstance: create)
    ..aOM<WebSessionBinding>(1, _omitFieldNames ? '' : 'binding',
        subBuilder: WebSessionBinding.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BindWebSessionResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BindWebSessionResponse copyWith(
          void Function(BindWebSessionResponse) updates) =>
      super.copyWith((message) => updates(message as BindWebSessionResponse))
          as BindWebSessionResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BindWebSessionResponse create() => BindWebSessionResponse._();
  @$core.override
  BindWebSessionResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BindWebSessionResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BindWebSessionResponse>(create);
  static BindWebSessionResponse? _defaultInstance;

  @$pb.TagNumber(1)
  WebSessionBinding get binding => $_getN(0);
  @$pb.TagNumber(1)
  set binding(WebSessionBinding value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasBinding() => $_has(0);
  @$pb.TagNumber(1)
  void clearBinding() => $_clearField(1);
  @$pb.TagNumber(1)
  WebSessionBinding ensureBinding() => $_ensure(0);
}

class ListWebSessionsRequest extends $pb.GeneratedMessage {
  factory ListWebSessionsRequest() => create();

  ListWebSessionsRequest._();

  factory ListWebSessionsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListWebSessionsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListWebSessionsRequest',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'synctv.provider.common'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListWebSessionsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListWebSessionsRequest copyWith(
          void Function(ListWebSessionsRequest) updates) =>
      super.copyWith((message) => updates(message as ListWebSessionsRequest))
          as ListWebSessionsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListWebSessionsRequest create() => ListWebSessionsRequest._();
  @$core.override
  ListWebSessionsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListWebSessionsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListWebSessionsRequest>(create);
  static ListWebSessionsRequest? _defaultInstance;
}

class ListWebSessionsResponse extends $pb.GeneratedMessage {
  factory ListWebSessionsResponse({
    $core.Iterable<WebSessionBinding>? bindings,
  }) {
    final result = create();
    if (bindings != null) result.bindings.addAll(bindings);
    return result;
  }

  ListWebSessionsResponse._();

  factory ListWebSessionsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListWebSessionsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListWebSessionsResponse',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'synctv.provider.common'),
      createEmptyInstance: create)
    ..pPM<WebSessionBinding>(1, _omitFieldNames ? '' : 'bindings',
        subBuilder: WebSessionBinding.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListWebSessionsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListWebSessionsResponse copyWith(
          void Function(ListWebSessionsResponse) updates) =>
      super.copyWith((message) => updates(message as ListWebSessionsResponse))
          as ListWebSessionsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListWebSessionsResponse create() => ListWebSessionsResponse._();
  @$core.override
  ListWebSessionsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListWebSessionsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListWebSessionsResponse>(create);
  static ListWebSessionsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<WebSessionBinding> get bindings => $_getList(0);
}

class UnbindWebSessionRequest extends $pb.GeneratedMessage {
  factory UnbindWebSessionRequest({
    $1.SourceProvider? provider,
  }) {
    final result = create();
    if (provider != null) result.provider = provider;
    return result;
  }

  UnbindWebSessionRequest._();

  factory UnbindWebSessionRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UnbindWebSessionRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UnbindWebSessionRequest',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'synctv.provider.common'),
      createEmptyInstance: create)
    ..aE<$1.SourceProvider>(1, _omitFieldNames ? '' : 'provider',
        enumValues: $1.SourceProvider.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UnbindWebSessionRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UnbindWebSessionRequest copyWith(
          void Function(UnbindWebSessionRequest) updates) =>
      super.copyWith((message) => updates(message as UnbindWebSessionRequest))
          as UnbindWebSessionRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UnbindWebSessionRequest create() => UnbindWebSessionRequest._();
  @$core.override
  UnbindWebSessionRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UnbindWebSessionRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UnbindWebSessionRequest>(create);
  static UnbindWebSessionRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $1.SourceProvider get provider => $_getN(0);
  @$pb.TagNumber(1)
  set provider($1.SourceProvider value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasProvider() => $_has(0);
  @$pb.TagNumber(1)
  void clearProvider() => $_clearField(1);
}

class UnbindWebSessionResponse extends $pb.GeneratedMessage {
  factory UnbindWebSessionResponse({
    $core.bool? removed,
  }) {
    final result = create();
    if (removed != null) result.removed = removed;
    return result;
  }

  UnbindWebSessionResponse._();

  factory UnbindWebSessionResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UnbindWebSessionResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UnbindWebSessionResponse',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'synctv.provider.common'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'removed')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UnbindWebSessionResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UnbindWebSessionResponse copyWith(
          void Function(UnbindWebSessionResponse) updates) =>
      super.copyWith((message) => updates(message as UnbindWebSessionResponse))
          as UnbindWebSessionResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UnbindWebSessionResponse create() => UnbindWebSessionResponse._();
  @$core.override
  UnbindWebSessionResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UnbindWebSessionResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UnbindWebSessionResponse>(create);
  static UnbindWebSessionResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get removed => $_getBF(0);
  @$pb.TagNumber(1)
  set removed($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRemoved() => $_has(0);
  @$pb.TagNumber(1)
  void clearRemoved() => $_clearField(1);
}

/// Safe binding metadata. Cookie values and other authentication material are
/// intentionally absent from this message.
class WebSessionBinding extends $pb.GeneratedMessage {
  factory WebSessionBinding({
    $fixnum.Int64? credentialId,
    $1.SourceProvider? provider,
    $core.String? serverId,
    $core.String? label,
    $core.int? cookieCount,
    $fixnum.Int64? expiresAt,
    $fixnum.Int64? createdAt,
    $fixnum.Int64? updatedAt,
  }) {
    final result = create();
    if (credentialId != null) result.credentialId = credentialId;
    if (provider != null) result.provider = provider;
    if (serverId != null) result.serverId = serverId;
    if (label != null) result.label = label;
    if (cookieCount != null) result.cookieCount = cookieCount;
    if (expiresAt != null) result.expiresAt = expiresAt;
    if (createdAt != null) result.createdAt = createdAt;
    if (updatedAt != null) result.updatedAt = updatedAt;
    return result;
  }

  WebSessionBinding._();

  factory WebSessionBinding.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory WebSessionBinding.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WebSessionBinding',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'synctv.provider.common'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'credentialId')
    ..aE<$1.SourceProvider>(2, _omitFieldNames ? '' : 'provider',
        enumValues: $1.SourceProvider.values)
    ..aOS(3, _omitFieldNames ? '' : 'serverId')
    ..aOS(4, _omitFieldNames ? '' : 'label')
    ..aI(5, _omitFieldNames ? '' : 'cookieCount',
        fieldType: $pb.PbFieldType.OU3)
    ..aInt64(6, _omitFieldNames ? '' : 'expiresAt')
    ..aInt64(7, _omitFieldNames ? '' : 'createdAt')
    ..aInt64(8, _omitFieldNames ? '' : 'updatedAt')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WebSessionBinding clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WebSessionBinding copyWith(void Function(WebSessionBinding) updates) =>
      super.copyWith((message) => updates(message as WebSessionBinding))
          as WebSessionBinding;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static WebSessionBinding create() => WebSessionBinding._();
  @$core.override
  WebSessionBinding createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static WebSessionBinding getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<WebSessionBinding>(create);
  static WebSessionBinding? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get credentialId => $_getI64(0);
  @$pb.TagNumber(1)
  set credentialId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCredentialId() => $_has(0);
  @$pb.TagNumber(1)
  void clearCredentialId() => $_clearField(1);

  @$pb.TagNumber(2)
  $1.SourceProvider get provider => $_getN(1);
  @$pb.TagNumber(2)
  set provider($1.SourceProvider value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasProvider() => $_has(1);
  @$pb.TagNumber(2)
  void clearProvider() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get serverId => $_getSZ(2);
  @$pb.TagNumber(3)
  set serverId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasServerId() => $_has(2);
  @$pb.TagNumber(3)
  void clearServerId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get label => $_getSZ(3);
  @$pb.TagNumber(4)
  set label($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasLabel() => $_has(3);
  @$pb.TagNumber(4)
  void clearLabel() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get cookieCount => $_getIZ(4);
  @$pb.TagNumber(5)
  set cookieCount($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasCookieCount() => $_has(4);
  @$pb.TagNumber(5)
  void clearCookieCount() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get expiresAt => $_getI64(5);
  @$pb.TagNumber(6)
  set expiresAt($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasExpiresAt() => $_has(5);
  @$pb.TagNumber(6)
  void clearExpiresAt() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get createdAt => $_getI64(6);
  @$pb.TagNumber(7)
  set createdAt($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasCreatedAt() => $_has(6);
  @$pb.TagNumber(7)
  void clearCreatedAt() => $_clearField(7);

  @$pb.TagNumber(8)
  $fixnum.Int64 get updatedAt => $_getI64(7);
  @$pb.TagNumber(8)
  set updatedAt($fixnum.Int64 value) => $_setInt64(7, value);
  @$pb.TagNumber(8)
  $core.bool hasUpdatedAt() => $_has(7);
  @$pb.TagNumber(8)
  void clearUpdatedAt() => $_clearField(8);
}

class ProviderCommonServiceApi {
  final $pb.RpcClient _client;

  ProviderCommonServiceApi(this._client);

  $async.Future<$0.PreparedMediaSource> prepareDirectUrl(
          $pb.ClientContext? ctx, $0.PrepareDirectUrlRequest request) =>
      _client.invoke<$0.PreparedMediaSource>(ctx, 'ProviderCommonService',
          'PrepareDirectUrl', request, $0.PreparedMediaSource());
  $async.Future<$0.PreparedMediaSource> prepareLiveProxy(
          $pb.ClientContext? ctx, $0.PrepareLiveProxyRequest request) =>
      _client.invoke<$0.PreparedMediaSource>(ctx, 'ProviderCommonService',
          'PrepareLiveProxy', request, $0.PreparedMediaSource());
  $async.Future<$0.PreparedMediaSource> prepareRtmp(
          $pb.ClientContext? ctx, $0.PrepareRtmpRequest request) =>
      _client.invoke<$0.PreparedMediaSource>(ctx, 'ProviderCommonService',
          'PrepareRtmp', request, $0.PreparedMediaSource());
  $async.Future<$0.PlaybackProxyPolicy> resolvePlaybackProxyPolicy(
          $pb.ClientContext? ctx,
          $0.ResolvePlaybackProxyPolicyRequest request) =>
      _client.invoke<$0.PlaybackProxyPolicy>(ctx, 'ProviderCommonService',
          'ResolvePlaybackProxyPolicy', request, $0.PlaybackProxyPolicy());
  $async.Future<$0.ProviderInstancesResponse> listAvailableProviderInstances(
          $pb.ClientContext? ctx,
          $0.ListAvailableProviderInstancesRequest request) =>
      _client.invoke<$0.ProviderInstancesResponse>(
          ctx,
          'ProviderCommonService',
          'ListAvailableProviderInstances',
          request,
          $0.ProviderInstancesResponse());
  $async.Future<$0.ProviderBackendsResponse> listProviderBackends(
          $pb.ClientContext? ctx, $0.ListProviderBackendsRequest request) =>
      _client.invoke<$0.ProviderBackendsResponse>(ctx, 'ProviderCommonService',
          'ListProviderBackends', request, $0.ProviderBackendsResponse());
  $async.Future<$0.ListProviderInstancesResponse> listProviderInstances(
          $pb.ClientContext? ctx, $0.ListProviderInstancesRequest request) =>
      _client.invoke<$0.ListProviderInstancesResponse>(
          ctx,
          'ProviderCommonService',
          'ListProviderInstances',
          request,
          $0.ListProviderInstancesResponse());
  $async.Future<$0.AddProviderInstanceResponse> addProviderInstance(
          $pb.ClientContext? ctx, $0.AddProviderInstanceRequest request) =>
      _client.invoke<$0.AddProviderInstanceResponse>(
          ctx,
          'ProviderCommonService',
          'AddProviderInstance',
          request,
          $0.AddProviderInstanceResponse());
  $async.Future<$0.UpdateProviderInstanceResponse> updateProviderInstance(
          $pb.ClientContext? ctx, $0.UpdateProviderInstanceRequest request) =>
      _client.invoke<$0.UpdateProviderInstanceResponse>(
          ctx,
          'ProviderCommonService',
          'UpdateProviderInstance',
          request,
          $0.UpdateProviderInstanceResponse());
  $async.Future<$0.DeleteProviderInstanceResponse> deleteProviderInstance(
          $pb.ClientContext? ctx, $0.DeleteProviderInstanceRequest request) =>
      _client.invoke<$0.DeleteProviderInstanceResponse>(
          ctx,
          'ProviderCommonService',
          'DeleteProviderInstance',
          request,
          $0.DeleteProviderInstanceResponse());
  $async.Future<$0.ReconnectProviderInstanceResponse> reconnectProviderInstance(
          $pb.ClientContext? ctx,
          $0.ReconnectProviderInstanceRequest request) =>
      _client.invoke<$0.ReconnectProviderInstanceResponse>(
          ctx,
          'ProviderCommonService',
          'ReconnectProviderInstance',
          request,
          $0.ReconnectProviderInstanceResponse());
  $async.Future<$0.EnableProviderInstanceResponse> enableProviderInstance(
          $pb.ClientContext? ctx, $0.EnableProviderInstanceRequest request) =>
      _client.invoke<$0.EnableProviderInstanceResponse>(
          ctx,
          'ProviderCommonService',
          'EnableProviderInstance',
          request,
          $0.EnableProviderInstanceResponse());
  $async.Future<$0.DisableProviderInstanceResponse> disableProviderInstance(
          $pb.ClientContext? ctx, $0.DisableProviderInstanceRequest request) =>
      _client.invoke<$0.DisableProviderInstanceResponse>(
          ctx,
          'ProviderCommonService',
          'DisableProviderInstance',
          request,
          $0.DisableProviderInstanceResponse());
  $async.Future<BindWebSessionResponse> bindWebSession(
          $pb.ClientContext? ctx, BindWebSessionRequest request) =>
      _client.invoke<BindWebSessionResponse>(ctx, 'ProviderCommonService',
          'BindWebSession', request, BindWebSessionResponse());
  $async.Future<ListWebSessionsResponse> listWebSessions(
          $pb.ClientContext? ctx, ListWebSessionsRequest request) =>
      _client.invoke<ListWebSessionsResponse>(ctx, 'ProviderCommonService',
          'ListWebSessions', request, ListWebSessionsResponse());
  $async.Future<UnbindWebSessionResponse> unbindWebSession(
          $pb.ClientContext? ctx, UnbindWebSessionRequest request) =>
      _client.invoke<UnbindWebSessionResponse>(ctx, 'ProviderCommonService',
          'UnbindWebSession', request, UnbindWebSessionResponse());
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
