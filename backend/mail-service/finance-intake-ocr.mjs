const OCR_LANGUAGES=(process.env.FINANCE_OCR_LANGUAGES||'ces,eng').split(',').map(value=>value.trim()).filter(Boolean)

export function createFinanceOcrSession({createWorkerImpl}={}) {
  let workerPromise=null
  async function getWorker(){
    if(!workerPromise){
      workerPromise=(async()=>{
        let createWorker=createWorkerImpl
        let oem=1
        if(!createWorker){
          const tesseract=await import('tesseract.js')
          createWorker=tesseract.createWorker
          oem=tesseract.OEM?.LSTM_ONLY??1
        }
        const options={cachePath:process.env.FINANCE_OCR_CACHE_PATH||'/tmp'}
        if(process.env.FINANCE_OCR_DEBUG==='1')options.logger=(message)=>console.log('Finance OCR',message.status,Math.round(Number(message.progress||0)*100))
        return createWorker(OCR_LANGUAGES,oem,options)
      })()
    }
    return workerPromise
  }
  return {
    async recognize(image){
      const worker=await getWorker()
      const result=await worker.recognize(Buffer.from(image))
      return {text:String(result?.data?.text||''),confidence:Number(result?.data?.confidence||0)}
    },
    async terminate(){
      if(!workerPromise)return
      const worker=await workerPromise.catch(()=>null)
      workerPromise=null
      if(worker)await worker.terminate().catch(()=>{})
    }
  }
}

export function needsInvoiceOcr(text) {
  return String(text||'').replace(/[^\p{L}\p{N}]/gu,'').length<120
}
