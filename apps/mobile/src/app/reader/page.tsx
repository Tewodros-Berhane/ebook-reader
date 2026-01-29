"use client";

import { useSearchParams } from "next/navigation";
import { ReaderClient } from "./ReaderClient";

export default function ReaderPage() {
  const searchParams = useSearchParams();
  const fileId = searchParams.get("fileId") ?? "";
  return <ReaderClient fileId={fileId} />;
}
