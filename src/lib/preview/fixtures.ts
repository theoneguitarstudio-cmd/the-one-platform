// Synthetic development data only. Never seed these into a real database.
export const previewUsers = [
  {id:"00000000-0000-4000-8000-000000000001",email:"student@example.invalid",role:"student",name:"Preview Student",path:"/student"},
  {id:"00000000-0000-4000-8000-000000000002",email:"teacher@example.invalid",role:"teacher",name:"Preview Teacher",path:"/teacher"},
  {id:"00000000-0000-4000-8000-000000000003",email:"admin@example.invalid",role:"admin",name:"Preview Admin",path:"/admin"},
];
export const previewPassword = "preview-demo-only";
const teacher={id:"00000000-0000-4000-8000-000000000102",teacher_profile_id:"00000000-0000-4000-8000-000000000102",user_id:previewUsers[1].id,public_slug:"preview-teacher",display_name:"Preview 老師小樂",avatar_url:null,bio:"合成師資資料，展示現有老師頁面，不能預約真正課程。",years_experience:3,teaching_modes:["online"],trial_price_twd:300,fixed_lesson_price_twd:1200,flexible_lesson_price_twd:1500,location_text:"Preview 線上教室",is_public:true,teaching_status:"active",teacher_specialties:[]};
const product={public_slug:"preview-private-lesson",name:"Preview 一對一體驗課",description:"僅展示既有商品畫面，不會收款、不會產生真正課程權益。",short_description:"合成商品 · 不收費",currency:"TWD",base_price_amount:300,product_type:"trial_lesson",seller_display_name:"Preview 老師小樂",is_purchasable:true,published_at:"2026-09-01T00:00:00Z"};
const order={id:"00000000-0000-4000-8000-000000000201",order_number:"PREVIEW-0001",buyer_user_id:previewUsers[0].id,status:"pending_payment",currency:"TWD",subtotal_amount:300,discount_amount:0,tax_amount:0,total_amount:300,payment_status:"unpaid",created_at:"2026-09-01T00:00:00Z",expires_at:null,paid_at:null,cancelled_at:null,profiles:[{display_name:"Preview Student"}],order_items:[{product_name_snapshot:product.name,quantity:1}]};
export const previewTables: Record<string, Record<string, unknown>[]> = {
  teacher_public_profiles:[teacher],teacher_profiles:[teacher],product_public_catalog:[product],orders:[order],
  order_items:[{id:"00000000-0000-4000-8000-000000000301",order_id:order.id,product_name_snapshot:product.name,product_type_snapshot:product.product_type,unit_price_amount:300,quantity:1,line_total_amount:300}],
  profiles:previewUsers.map(u=>({user_id:u.id,display_name:u.name,account_status:"active"})),
  user_roles:previewUsers.map(u=>({user_id:u.id,role:u.role})),
  specialties:[],learning_map_stages:[],teacher_specialties:[],teacher_stage_capabilities:[],payments:[],payment_submissions:[],
};
