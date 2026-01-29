"use client";

import { useEffect, useRef } from "react";
import ePub from "epubjs";

type ReaderSource = string | ArrayBuffer;

type ReaderProps = {
  src: ReaderSource;
  cfi?: string;
  onLocationChange?: (cfi: string) => void;
  onError?: (message: string) => void;
  className?: string;
};

export function Reader({ src, cfi, onLocationChange, onError, className = "" }: ReaderProps) {
  const containerRef = useRef<HTMLDivElement | null>(null);
  const bookRef = useRef<any>(null);
  const renditionRef = useRef<any>(null);
  const callbacksRef = useRef({ onLocationChange, onError });
  const readyRef = useRef<Promise<unknown> | null>(null);
  const lastCfiRef = useRef<string | undefined>(undefined);

  useEffect(() => {
    callbacksRef.current = { onLocationChange, onError };
  }, [onLocationChange, onError]);

  useEffect(() => {
    if (!containerRef.current || !src) return;

    const isBinary = src instanceof ArrayBuffer || ArrayBuffer.isView(src as ArrayBufferView);
    const binary =
      src instanceof ArrayBuffer
        ? src
        : ArrayBuffer.isView(src as ArrayBufferView)
          ? (src as ArrayBufferView).buffer.slice(
              (src as ArrayBufferView).byteOffset,
              (src as ArrayBufferView).byteOffset + (src as ArrayBufferView).byteLength,
            )
          : null;
    const book = isBinary && binary ? ePub(binary, { openAs: "binary" }) : ePub(src as string);

    const reportError = (err: unknown) => {
      const message = err instanceof Error ? err.message : String(err);
      callbacksRef.current.onError?.(message);
    };

    book.on("error", reportError);
    book.on("openFailed", reportError);

    const rendition = book.renderTo(containerRef.current, {
      width: "100%",
      height: "100%",
    });

    bookRef.current = book;
    renditionRef.current = rendition;

    readyRef.current = book.ready
      .then(() => {
        lastCfiRef.current = cfi;
        return rendition.display(cfi || undefined);
      })
      .catch(reportError);

    rendition.on("relocated", (location: any) => {
      const nextCfi = location?.start?.cfi;
      if (nextCfi) callbacksRef.current.onLocationChange?.(nextCfi);
    });

    return () => {
      try {
        readyRef.current = null;
        rendition.destroy();
        book.destroy();
      } catch {
        // no-op cleanup
      }
    };
  }, [src]);

  useEffect(() => {
    const rendition = renditionRef.current;
    if (!rendition || !cfi || lastCfiRef.current === cfi) return;
    lastCfiRef.current = cfi;
    readyRef.current
      ?.then(() => rendition.display(cfi))
      .catch((err: unknown) => {
        const message = err instanceof Error ? err.message : String(err);
        callbacksRef.current.onError?.(message);
      });
  }, [cfi]);

  return <div ref={containerRef} className={`h-full w-full ${className}`} />;
}
