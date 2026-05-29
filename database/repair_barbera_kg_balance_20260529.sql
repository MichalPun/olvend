select public.apply_stock_movements_v13(
  '[
    {
      "product_id": 21,
      "batch_id": null,
      "from_stock_location_id": 1,
      "to_stock_location_id": null,
      "movement_type": "adjustment",
      "quantity_base_units": 17982,
      "unit_price": 240,
      "reference_type": "data_repair",
      "reference_id": "repair-barbera-kg-20260529",
      "note": "Oprava jednotek Barbera 1870 1 kg: stav byl uložen jako 18000 kg místo 18 kg"
    }
  ]'::jsonb
) as result;
