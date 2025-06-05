import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { logger } from '../utils/logger';

export interface AuthRequest extends Request {
  user?: {
    id: string;
    role: string;
  };
}

/**
 * JWT 认证中间件
 */
export const authMiddleware = (req: AuthRequest, res: Response, next: NextFunction): any => {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader) {
      return res.status(401).json({
        success: false,
        error: 'Authorization header is required'
      });
    }

    const token = authHeader.split(' ')[1]; // Bearer <token>
    
    if (!token) {
      return res.status(401).json({
        success: false,
        error: 'Token is required'
      });
    }

    // 验证 token
    const jwtSecret = process.env.JWT_SECRET || 'newhttps-default-secret';
    const decoded = jwt.verify(token, jwtSecret) as any;
    
    req.user = {
      id: decoded.id || decoded.sub,
      role: decoded.role || 'user'
    };

    logger.debug(`Authenticated user: ${req.user.id}`);
    next();
  } catch (error) {
    logger.error('Authentication failed:', error);
    
    if (error instanceof jwt.JsonWebTokenError) {
      return res.status(401).json({
        success: false,
        error: 'Invalid token'
      });
    }
    
    if (error instanceof jwt.TokenExpiredError) {
      return res.status(401).json({
        success: false,
        error: 'Token expired'
      });
    }

    return res.status(500).json({
      success: false,
      error: 'Authentication error'
    });
  }
};

/**
 * 可选认证中间件 - 如果有 token 则验证，没有则跳过
 */
export const optionalAuthMiddleware = (req: AuthRequest, res: Response, next: NextFunction) => {
  const authHeader = req.headers.authorization;
  
  if (!authHeader) {
    return next();
  }

  authMiddleware(req, res, next);
};

/**
 * 生成 JWT token
 */
export const generateToken = (payload: any, expiresIn: string = '24h'): string => {
  const jwtSecret = process.env.JWT_SECRET || 'newhttps-default-secret';
  return jwt.sign(payload, jwtSecret, { expiresIn } as any);
};

/**
 * 验证 token
 */
export const verifyToken = (token: string): any => {
  const jwtSecret = process.env.JWT_SECRET || 'newhttps-default-secret';
  return jwt.verify(token, jwtSecret);
};
