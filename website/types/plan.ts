export type Plan = {
  id: string;
  name: "Standard" | "Deluxe" | "Premium";
  price: number;
  price_monthly: number | null;
  tagline: string | null;
  features: string[];
  is_featured: boolean;
  is_active: boolean;
  sort_order: number;
};
