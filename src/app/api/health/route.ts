import { NextResponse } from "next/server";

export function GET() {
  return NextResponse.json({
    status: "ok",
    app: "the-one-platform",
    timestamp: new Date().toISOString(),
  });
}
