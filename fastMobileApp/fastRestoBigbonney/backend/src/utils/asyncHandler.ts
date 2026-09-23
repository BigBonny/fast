import { Request, Response, NextFunction, RequestHandler } from 'express';

export function asyncHandler<T extends RequestHandler>(fn: T): T {
  return (async (req: Request, res: Response, next: NextFunction) => {
    try {
      await fn(req, res, next);
    } catch (err) {
      next(err);
    }
  }) as T;
}
