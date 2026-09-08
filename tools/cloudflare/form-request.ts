/** Keep the existing Next Server Action 1 MiB form limit at the Worker boundary. */
export async function bufferFormRequest(request: Request): Promise<Request | Response> {
    const type = request.headers.get("content-type") ?? "";
    if (request.method !== "POST" || !/^(multipart\/form-data|application\/x-www-form-urlencoded)(;|$)/i.test(type) || !request.body)
        return request;
    const reader = request.body.getReader();
    const chunks: Uint8Array[] = [];
    let size = 0;
    let timedOut = false;
    const timer = setTimeout(() => { timedOut = true; void reader.cancel(); }, 10000);
    try {
        while (true) {
            const { done, value } = await reader.read();
            if (timedOut)
                return new Response("Request timeout", { status: 408 });
            if (done)
                break;
            size += value.byteLength;
            if (size > 1024 * 1024) {
                await reader.cancel();
                return new Response("Form too large", { status: 413 });
            }
            chunks.push(value);
        }
    }
    catch {
        return new Response("Invalid request body", { status: 400 });
    }
    finally {
        clearTimeout(timer);
        reader.releaseLock();
    }
    const bytes = new Uint8Array(size);
    let offset = 0;
    for (const chunk of chunks) {
        bytes.set(chunk, offset);
        offset += chunk.byteLength;
    }
    // One delegation only. A complete body also avoids the local proxy's early-rejection stream race.
    return new Request(request, { body: bytes });
}
