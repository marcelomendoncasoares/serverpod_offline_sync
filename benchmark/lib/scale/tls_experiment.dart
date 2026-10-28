/// Identifies this isolated benchmark build without changing Cloud config.
const tlsExperimentVariant = 'pipeline8-concurrent-v2';

/// The requested native TLS connector is installed before Serverpod starts.
const tlsExperimentNative = true;

/// Maximum in-flight statements on one PostgreSQL connection.
const tlsExperimentPipelineDepth = 8;
