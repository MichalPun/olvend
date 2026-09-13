// Presentation layer: move the existing controls, preserving their IDs and save handlers.
export function initPlanogramCard(form) {
  const body = form.querySelector('.modal-body')
  const originalGrid = body.querySelector('.form-grid')
  const fields = [...originalGrid.children]
  const input = id => form.querySelector(`#${id}`)
  const tabs = document.createElement('div')
  tabs.className = 'planogram-tabs'
  tabs.setAttribute('aria-label', 'Části karty pozice')
  body.prepend(tabs)
  const panels = new Map()
  function panel(key, label) {
    const button = document.createElement('button')
    button.type = 'button'
    button.textContent = label
    button.dataset.cardTab = key
    button.setAttribute('aria-controls', `planogram-panel-${key}`)
    button.addEventListener('click', () => show(key))
    tabs.append(button)
    const section = document.createElement('section')
    section.id = `planogram-panel-${key}`
    section.className = 'planogram-card-panel'
    section.setAttribute('aria-label', label)
    body.insertBefore(section, originalGrid)
    panels.set(key, section)
    return section
  }
  const position = panel('position', 'Pozice')
  const replacements = panel('replacements', 'Náhrady')
  const plan = panel('plan', 'Plán změny')
  const summary = document.createElement('div')
  summary.className = 'planogram-card-summary'
  position.append(summary)
  function grid(parent) {
    const node = document.createElement('div')
    node.className = 'form-grid'
    parent.append(node)
    return node
  }
  function disclosure(parent, label) {
    const details = document.createElement('details')
    const heading = document.createElement('summary')
    heading.textContent = label
    details.append(heading)
    parent.append(details)
    return grid(details)
  }
  const mainGrid = grid(position)
  const finances = disclosure(position, 'Finanční pravidla a příspěvky')
  const technical = disclosure(position, 'Poznámka a technické údaje')
  const replacementGrid = grid(replacements)
  const planGrid = grid(plan)
  const financialIds = new Set(['slotCustomerPrice', 'slotSettlementType', 'slotSubsidyAmount', 'slotSubsidyPayer', 'slotSubsidyBillingEnabled', 'slotSubsidyNote'])
  const technicalIds = new Set(['slotProductSku', 'slotSortOrder', 'slotNote', 'slotActive', 'slotFillPercent'])
  const replacementIds = new Set(['slotProductFamily', 'slotProductVariant', 'slotSubstitutionPolicy', 'slotAllowedSubstitutes'])
  const planIds = new Set(['slotPlannedProductName', 'slotPlannedProductSku', 'slotPlannedPrice', 'slotPendingChangeMode', 'slotOperatorInstruction'])
  for (const field of fields) {
    const id = field.querySelector('input,select,textarea')?.id
    const destination = financialIds.has(id) ? finances : technicalIds.has(id) ? technical : replacementIds.has(id) ? replacementGrid : planIds.has(id) ? planGrid : mainGrid
    destination.append(field)
  }
  originalGrid.remove()
  body.querySelector(':scope > .helper-line')?.remove()
  const note = document.createElement('p')
  note.className = 'planogram-card-hint'
  note.textContent = 'Povolené náhrady se používají při vychystání a doplnění. U vypsaných náhrad zachovej označení SKU produktů.'
  replacements.prepend(note)
  const preview = document.createElement('p')
  preview.className = 'planogram-card-hint'
  plan.append(preview)
  function show(key) {
    for (const [id, section] of panels) section.hidden = id !== key
    tabs.querySelectorAll('button').forEach(b => b.setAttribute('aria-pressed', String(b.dataset.cardTab === key)))
  }
  function refresh() {
    const coffee = Boolean(input('planogramCoffeeContainerId').value)
    const unit = coffee ? input('slotContainerUnit').value : 'ks'
    const qty = input('slotCurrentUnits').value
    const cap = input('slotCapacity').value
    summary.replaceChildren()
    const product = document.createElement('strong')
    product.textContent = input('slotProductName').value || 'Nová pozice'
    const stock = document.createElement('span')
    stock.textContent = `${qty || '—'} / ${cap || '—'} ${unit}`
    summary.append(product, stock)
    const target = input('slotPlannedProductName').value.trim()
    preview.textContent = !target ? 'Vyber následující produkt a způsob přechodu.' : input('slotPendingChangeMode').value === 'full_swap'
      ? `Při návštěvě vrátit staré zboží do vozidla a vložit ${target}. Při změně ceny operátor potvrdí její nastavení na automatu.`
      : `Po doprodeji přejít na ${target}. Smíšená zásoba zůstává evidovaná podle skutečného doplnění.`
  }
  form.addEventListener('input', refresh)
  form.addEventListener('change', refresh)
  // Native validation must be able to focus fields in collapsed sections and other tabs.
  form.addEventListener('invalid', event => {
    const section = event.target.closest('.planogram-card-panel')
    if (section) show([...panels].find(([, node]) => node === section)[0])
    const details = event.target.closest('details')
    if (details) details.open = true
  }, true)
  return {
    open(tab = 'position') {
      body.querySelectorAll('details').forEach(d => { d.open = false })
      show(tab)
      refresh()
    }
  }
}

export function planogramReplacementLabel(slot) {
  if (slot.substitution_policy === 'same_family') return `↔ Příchutě ${slot.product_family || 'stejné skupiny'}`
  if (slot.substitution_policy === 'approved_list') return '↔ Schválené náhrady'
  if (slot.substitution_policy === 'operator_choice') return '↔ Výběr operátora'
  return 'Konkrétní produkt'
}

export function bulkPlanogramCandidates(slots, family) {
  return slots.filter(slot => slot.active !== false && slot.product_family === family && !slot.planned_product_name && !slot.planned_product_sku && !slot.pending_product_sku)
}

export function hasPlanogramChange(slot) {
  const nextName = String(slot.planned_product_name || '').trim()
  const nextSku = String(slot.planned_product_sku || '').trim()
  if (!nextName && !nextSku) return false
  const currentSku = String(slot.product_sku || '').trim()
  const differentProduct = nextSku && currentSku ? nextSku !== currentSku : nextName !== String(slot.product_name || '').trim()
  const differentPrice = slot.planned_price_czk != null && slot.price_czk != null && Number(slot.planned_price_czk) !== Number(slot.price_czk)
  return Boolean(differentProduct || differentPrice || Number(slot.changeover_new_units || 0) > 0)
}
