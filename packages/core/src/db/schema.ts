import Dexie, { Table } from "dexie";
import type { LocalBook, LocalFile } from "../types/index";

export class LuminaDB extends Dexie {
  books!: Table<LocalBook, string>;
  files!: Table<LocalFile, string>;

  constructor() {
    super("lumina_reader");
    this.version(1).stores({
      books: "fileId, timestamp, isDirty, downloadStatus",
    });
    this.version(2).stores({
      books: "fileId, timestamp, isDirty, downloadStatus",
      files: "fileId",
    });
  }
}

export const db = new LuminaDB();
