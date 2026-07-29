import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.43.4'

const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

const supabase = createClient(supabaseUrl, supabaseServiceKey)

export async function getEvidenceFile(evidenceId: number) {
  try {
    // 1. Get file path from case_evidence
    const { data: caseData, error: caseError } = await supabase
      .from('case_evidence')
      .select('id, storage_path, evidence_no, file_size, file_ext')
      .eq('id', evidenceId)
      .single()

    if (caseError || !caseData) {
      return {
        error: `증거 ${evidenceId} 찾기 실패`,
        status: 404,
      }
    }

    // 2. Download file from storage
    const { data: fileData, error: downloadError } = await supabase.storage
      .from('case-files')
      .download(caseData.storage_path)

    if (downloadError || !fileData) {
      return {
        error: `파일 다운로드 실패: ${caseData.storage_path}`,
        status: 500,
      }
    }

    // 3. Extract text based on file type
    let extractedText = ''
    let totalPages = 0

    if (caseData.file_ext === 'pdf') {
      // PDF 텍스트 추출은 별도 처리 필요
      // 일단 파일 크기로 페이지 수 추정
      totalPages = Math.max(1, Math.floor(caseData.file_size / 2500))
      extractedText = `[PDF 파일] ${caseData.evidence_no} (${caseData.file_size} bytes, 약 ${totalPages}쪽)`
    } else {
      extractedText = `[파일] ${caseData.evidence_no} (${caseData.file_ext})`
      totalPages = 1
    }

    return {
      success: true,
      evidence_id: evidenceId,
      evidence_no: caseData.evidence_no,
      file_size: caseData.file_size,
      extracted_text: extractedText,
      total_pages: totalPages,
      file_ext: caseData.file_ext,
    }
  } catch (err) {
    return {
      error: `함수 오류: ${err.message}`,
      status: 500,
    }
  }
}

// Deno HTTP handler
Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 })
  }

  try {
    const { evidence_id } = await req.json()
    const result = await getEvidenceFile(evidence_id)
    return new Response(JSON.stringify(result), {
      headers: { 'Content-Type': 'application/json' },
      status: result.status || 200,
    })
  } catch (err) {
    return new Response(
      JSON.stringify({ error: err.message }),
      { status: 400, headers: { 'Content-Type': 'application/json' } }
    )
  }
})
