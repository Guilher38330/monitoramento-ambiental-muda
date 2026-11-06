import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

/// Perfis de acesso exigidos pelo requisito AM-01:
/// - Administrador: acesso completo a dados abertos, sigilosos, cadastro e administração.
/// - Equipe Técnica: acesso a dados técnicos sigilosos, coleta em campo e resolução de conflitos.
/// - Empresa Contratante: acesso restrito somente a dados abertos, cronogramas e indicadores consolidados.
enum UserRole {
  admin,
  tecnico,
  empresa;

  String get label {
    switch (this) {
      case UserRole.admin:
        return 'Administrador';
      case UserRole.tecnico:
        return 'Equipe Técnica';
      case UserRole.empresa:
        return 'Empresa Contratante';
    }
  }

  String get shortBadge {
    switch (this) {
      case UserRole.admin:
        return 'ADMIN';
      case UserRole.tecnico:
        return 'TÉCNICO';
      case UserRole.empresa:
        return 'EMPRESA';
    }
  }

  String get description {
    switch (this) {
      case UserRole.admin:
        return 'Acesso total: gestão de projetos, dados sigilosos (CAR/CPF/PSA), auditoria e sincronização.';
      case UserRole.tecnico:
        return 'Operação em campo: coleta georreferenciada offline, consulta técnica e dados sigilosos autorizados.';
      case UserRole.empresa:
        return 'Consulta contratante: visualização de dados abertos, cronogramas, documentos públicos e indicadores.';
    }
  }

  IconData get icon {
    switch (this) {
      case UserRole.admin:
        return Icons.admin_panel_settings_rounded;
      case UserRole.tecnico:
        return Icons.engineering_rounded;
      case UserRole.empresa:
        return Icons.business_rounded;
    }
  }

  Color get badgeColor {
    switch (this) {
      case UserRole.admin:
        return const Color(0xFF1B5E20); // Verde escuro institucional
      case UserRole.tecnico:
        return const Color(0xFF0277BD); // Azul técnico
      case UserRole.empresa:
        return const Color(0xFFEF6C00); // Âmbar corporativo
    }
  }

  /// Requisito AM-01: respeito às permissões de dados sigilosos e abertos.
  bool get canViewConfidentialData =>
      this == UserRole.admin || this == UserRole.tecnico;

  /// Requisito AM-01 / AM-05: apenas Admin e Equipe Técnica realizam coletas de campo.
  bool get canRegisterFieldData =>
      this == UserRole.admin || this == UserRole.tecnico;

  /// Requisito AM-04: resolução de conflitos de sincronização.
  bool get canResolveSyncConflicts =>
      this == UserRole.admin || this == UserRole.tecnico;

  /// Gestão administrativa exclusiva.
  bool get canManageSystem => this == UserRole.admin;

  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (r) => r.name.toLowerCase() == value.toLowerCase(),
      orElse: () => UserRole.empresa,
    );
  }
}

class AppUser {
  final String id;
  final String name;
  final String email;
  final String organization;
  final String registrationCode;
  final UserRole role;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.organization,
    required this.registrationCode,
    required this.role,
  });

  bool get canViewConfidentialData => role.canViewConfidentialData;
  bool get canRegisterFieldData => role.canRegisterFieldData;
  bool get canResolveSyncConflicts => role.canResolveSyncConflicts;

  /// Mascara CPF ou código sigiloso caso o perfil não tenha permissão (AM-01).
  String formatConfidentialText(
    String rawValue, {
    String maskedFallback = '•••.•••.•••-•• (Restrito - LGPD/Sigilo)',
  }) {
    if (canViewConfidentialData) return rawValue;
    return maskedFallback;
  }

  /// Mascara valores financeiros de contratos/PSA caso o perfil seja Empresa (AM-01).
  String formatConfidentialCurrency(double value) {
    if (canViewConfidentialData) {
      final formatted = value.toStringAsFixed(2).replaceAll('.', ',');
      return 'R\$ $formatted';
    }
    return 'Sigilo Contratual (Restrito ao perfil ${role.shortBadge})';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'organization': organization,
      'registrationCode': registrationCode,
      'role': role.name,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] as String,
      name: map['name'] as String,
      email: map['email'] as String,
      organization: map['organization'] as String,
      registrationCode: map['registrationCode'] as String,
      role: UserRole.fromString(map['role'] as String),
    );
  }

  /// Perfis pré-configurados para demonstração rápida (1 toque na tela de Login).
  static const List<AppUser> demoUsers = [
    AppUser(
      id: 'usr-admin-01',
      name: 'Dra. Helena Vasconcelos',
      email: 'admin@muda.org.br',
      organization: 'Coordenação Geral — Programa Muda & PSA',
      registrationCode: 'ADM-2026-001',
      role: UserRole.admin,
    ),
    AppUser(
      id: 'usr-tec-01',
      name: 'Eng. Lucas Albuquerque',
      email: 'tecnico@muda.org.br',
      organization: 'Equipe Técnica de Campo — CREA 149280/D',
      registrationCode: 'TEC-2026-014',
      role: UserRole.tecnico,
    ),
    AppUser(
      id: 'usr-emp-01',
      name: 'Mariana Costa (ESG Corporativo)',
      email: 'empresa@parceira.com.br',
      organization: 'HidroEnergia S.A. — Financiadora Parceira',
      registrationCode: 'EMP-2026-089',
      role: UserRole.empresa,
    ),
  ];
}

/// Serviço simulado de autenticação e assinatura JWT (HMAC-SHA256) conforme Premissas Comuns.
class JwtAuthSimulator {
  static const String _secretKey =
      'muda_psa_environmental_monitoring_jwt_secret_2026';

  /// Gera um Token JWT assinado (`header.payload.signature`) com escopos de segurança do perfil.
  static String generateToken(AppUser user, {DateTime? issuedAt}) {
    final now = issuedAt ?? DateTime.now().toUtc();
    final exp = now.add(const Duration(hours: 12));

    final header = {
      'alg': 'HS256',
      'typ': 'JWT',
    };

    final payload = {
      'sub': user.id,
      'name': user.name,
      'email': user.email,
      'role': user.role.name,
      'org': user.organization,
      'confidential_access': user.canViewConfidentialData,
      'field_write_access': user.canRegisterFieldData,
      'iat': now.millisecondsSinceEpoch ~/ 1000,
      'exp': exp.millisecondsSinceEpoch ~/ 1000,
    };

    final encodedHeader = _base64UrlEncode(utf8.encode(jsonEncode(header)));
    final encodedPayload = _base64UrlEncode(utf8.encode(jsonEncode(payload)));
    final signingInput = '$encodedHeader.$encodedPayload';

    final hmac = Hmac(sha256, utf8.encode(_secretKey));
    final digest = hmac.convert(utf8.encode(signingInput));
    final signature = _base64UrlEncode(digest.bytes);

    return '$signingInput.$signature';
  }

  /// Valida a integridade da assinatura HMAC-SHA256 e a expiração do token JWT.
  static bool validateToken(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return false;

    final signingInput = '${parts[0]}.${parts[1]}';
    final hmac = Hmac(sha256, utf8.encode(_secretKey));
    final expectedSignature =
        _base64UrlEncode(hmac.convert(utf8.encode(signingInput)).bytes);

    if (parts[2] != expectedSignature) return false;

    try {
      final payloadMap = decodePayload(token);
      final exp = payloadMap['exp'] as int?;
      if (exp == null) return false;
      final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      return exp >= nowSec;
    } catch (_) {
      return false;
    }
  }

  /// Decodifica o payload JSON do Token JWT para inspeção e auditoria.
  static Map<String, dynamic> decodePayload(String token) {
    final parts = token.split('.');
    if (parts.length != 3) {
      throw const FormatException('Token JWT inválido.');
    }
    final normalized = base64Url.normalize(parts[1]);
    final jsonString = utf8.decode(base64Url.decode(normalized));
    return jsonDecode(jsonString) as Map<String, dynamic>;
  }

  /// Gera hash SHA-256 para armazenamento seguro de credenciais locais.
  static String hashPassword(String plainPassword) {
    return sha256.convert(utf8.encode('salt_muda_2026:$plainPassword')).toString();
  }

  static String _base64UrlEncode(List<int> bytes) {
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}
