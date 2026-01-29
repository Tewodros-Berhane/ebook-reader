"use client";

import { useEffect, useRef } from "react";
import ePub from "epubjs";

type ReaderSource = string | Blob | ArrayBuffer;

type ReaderProps = {
  src: ReaderSource;
  cfi?: string;
  onLocationChange?: (cfi: string) => void;
  className?: string;
};

export function Reader({ src, cfi, onLocationChange, className = "" }: ReaderProps) {
  const containerRef = useRef<HTMLDivElement | null>(null);
  const bookRef = useRef<any>(null);
  const renditionRef = useRef<any>(null);

  useEffect(() => {
    if (!containerRef.current || !src) return;

    const book = ePub(src as any);
    const rendition = book.renderTo(containerRef.current, {
      width: "100%",
      height: "100%",
    });

    bookRef.current = book;
    renditionRef.current = rendition;

    rendition.display(cfi || undefined);
    rendition.on("relocated", (location: any) => {
      const nextCfi = location?.start?.cfi;
      if (nextCfi) onLocationChange?.(nextCfi);
    });

    return () => {
      try {
        rendition.destroy();
        book.destroy();
      } catch {
        // no-op cleanup
      }
    };
  }, [src, cfi, onLocationChange]);

  return <div ref={containerRef} className={`h-full w-full ${className}`} />;
}
