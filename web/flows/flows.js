// Pure logic behind the flows menu and the create-process form. No DOM here, so it can be tested
// and reused. Field names follow https://developer.unico.io/developers/api-reference/post-processes

export function filterFlows(flows, { group, region }) {
  return flows.filter((flow) => flow.group === group && (region === 'all' || flow.region === region));
}

// Drops empty values, so the API only receives what the user filled in.
function compact(object) {
  return Object.fromEntries(Object.entries(object).filter(([, value]) => value !== undefined && value !== ''));
}

// `fields` holds the form values as strings, plus `documentFiles` as base64 strings.
export function buildProcessBody(flow, fields, callbackUri) {
  const body = {
    flow: flow.id,
    callbackUri,
    person: compact({
      duiType: fields.duiType,
      duiValue: fields.duiValue,
      friendlyName: fields.friendlyName,
      email: fields.email,
      phone: fields.phone,
    }),
  };

  if (flow.extraFields.includes('document') && fields.documentFiles?.length) {
    body.document = compact({
      purpose: fields.documentPurpose,
      files: fields.documentFiles.map((data) => ({ data })),
    });
  }
  if (flow.extraFields.includes('useCase') && fields.useCase) {
    body.useCase = fields.useCase;
  }
  if (flow.extraFields.includes('references') && fields.referenceProcessId) {
    body.references = [{ referenceType: 'REFERENCE_TYPE_PROCESS_ID', referenceContent: fields.referenceProcessId }];
  }

  if (fields.expiresIn) body.expiresIn = fields.expiresIn;
  if (fields.purpose) body.purpose = fields.purpose;

  const contextualization = compact({
    company_name: fields.companyName,
    currency: fields.currency,
    price: fields.price ? Number(fields.price) : undefined,
    locale: fields.reason ? { [fields.locale]: { reason: fields.reason } } : undefined,
  });
  if (Object.keys(contextualization).length) body.contextualization = contextualization;

  return body;
}
