// Pure logic behind the create-process form. No DOM and no imports, so it can be tested, reused and served
// as is to the request preview on the form. Field names follow
// https://developer.unico.io/developers/api-reference/post-processes

// Drops empty values, so the API only receives what the user filled in.
function compact(object) {
  return Object.fromEntries(Object.entries(object).filter(([, value]) => value !== undefined && value !== ''));
}

// `fields` holds the form values as strings, plus `documentFiles` as base64 strings. The flow is whatever the
// user typed: the app doesn't know which flows the account has, so a wrong or disabled one fails on creation.
// `withDocument`, `withReferences` and `withContextualization` are the checkboxes that turn the extra fields on.
export function buildProcessBody(fields, callbackUri) {
  const body = { flow: fields.flow?.trim(), callbackUri };

  // Not every flow asks for the person's document. Without its number, the type alone means nothing.
  const person = compact({
    duiType: fields.duiValue ? fields.duiType : undefined,
    duiValue: fields.duiValue,
    friendlyName: fields.friendlyName,
    email: fields.email,
    phone: fields.phone,
  });
  if (Object.keys(person).length) body.person = person;

  if (fields.withDocument && fields.documentFiles?.length) {
    body.document = compact({
      purpose: fields.documentPurpose,
      files: fields.documentFiles.map((data) => ({ data })),
    });
  }
  if (fields.withReferences && fields.useCase) body.useCase = fields.useCase;
  if (fields.withReferences && fields.referenceProcessId) {
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
  if (fields.withContextualization && Object.keys(contextualization).length) body.contextualization = contextualization;

  return body;
}
