import { ReaderClient } from "./ReaderClient";

type ReaderPageProps = {
  params: { fileId: string };
};

export default function ReaderPage({ params }: ReaderPageProps) {
  return <ReaderClient fileId={params.fileId} />;
}

export async function generateStaticParams() {
  return [{ fileId: "placeholder" }];
}

export const dynamicParams = false;
