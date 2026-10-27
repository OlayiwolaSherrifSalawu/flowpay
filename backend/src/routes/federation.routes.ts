import { Router, type Request, type Response } from 'express';
import { FlowPayError } from '../core/errors.js';
import { buildStellarToml, federationById, federationByName, homeDomainFor } from '../stellar/federation.js';

/**
 * Public SEP-1 / SEP-2 endpoints, mounted at the site root:
 *   GET /.well-known/stellar.toml
 *   GET /federation?q=<name*domain|G...>&type=<name|id>
 */
export const federationRouter = Router();

// SEP-1 and SEP-2 require these to be readable from any origin.
federationRouter.use(['/.well-known/stellar.toml', '/federation'], (_req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  next();
});

federationRouter.get('/.well-known/stellar.toml', (req: Request, res: Response) => {
  const domain = homeDomainFor(req.get('host'));
  if (!domain) return res.status(500).type('text/plain').send('# Home domain not configured\n');
  res.type('text/plain').send(buildStellarToml(domain));
});

federationRouter.get('/federation', async (req: Request, res: Response) => {
  const domain = homeDomainFor(req.get('host'));
  const q = String(req.query.q ?? '');
  const type = String(req.query.type ?? '');
  try {
    if (!domain) throw new FlowPayError('Home domain not configured.', 500, 'FEDERATION_DISABLED');
    if (type === 'name') return res.json(await federationByName(q, domain));
    if (type === 'id') return res.json(await federationById(q, domain));
    return res.status(501).json({ detail: `Federation type "${type}" is not supported.` });
  } catch (err) {
    const status = err instanceof FlowPayError ? err.statusCode : 500;
    res.status(status).json({ detail: (err as Error).message });
  }
});
