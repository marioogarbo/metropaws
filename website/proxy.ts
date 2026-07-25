import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

const PUBLIC_ROUTES = ['/', '/about', '/admin/login', '/register', '/forgot-password', '/reset-password', '/privacy-policy', '/terms-of-service'];

export function proxy(req: NextRequest) {
  const { pathname } = req.nextUrl;
  const token = req.cookies.get('mp_token')?.value;
  const role = req.cookies.get('mp_role')?.value;

  const isPublic = PUBLIC_ROUTES.includes(pathname);

  if (!token && !isPublic) {
    return NextResponse.redirect(new URL('/admin/login', req.url));
  }

  // Don't redirect away from the public homepage even when authenticated
  if (token && isPublic && pathname !== '/') {
    return NextResponse.redirect(new URL(role === 'admin' ? '/admin' : '/member', req.url));
  }

  return NextResponse.next();
}

export const config = {
  matcher: ['/((?!api|_next/static|_next/image|favicon.ico|.*\\.(?:png|jpg|jpeg|svg|ico|webp)).*)'],
};
