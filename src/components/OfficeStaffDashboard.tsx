import React, { useState, useEffect } from 'react';
import { Package, Check, Plus, MapPin, Clock, Image as ImageIcon, ArrowRight, CreditCard, DollarSign } from 'lucide-react';
import { supabase } from '../lib/supabase';

interface OfficeStaffDashboardProps {
  userId: string;
}

interface Region {
  id: string;
  name: string;
}

interface ShippingRequest {
  request_id: string;
  user_id: string;
  user_email: string;
  pickup_location: string;
  delivery_location: string;
  description: string;
  image_url: string;
  status: string;
  delivery_fee: number;
  order_value: number;
  created_at: string;
  driver_email?: string;
}

interface ShippingForm {
  senderName: string;
  senderPhone: string;
  recipientName: string;
  recipientPhone: string;
  deliveryLocation: string;
  deliveryType: 'office' | 'home';
  description: string;
  orderValue: string;
  deliveryFee: string;
  isPaid: boolean;
  imageFile: File | null;
  imageUrl: string;
}

export function OfficeStaffDashboard({ userId }: OfficeStaffDashboardProps) {
  const [view, setView] = useState<'main' | 'register' | 'storage' | 'delivery'>('main');
  const [assignedRegion, setAssignedRegion] = useState<Region | null>(null);
  const [shipments, setShipments] = useState<ShippingRequest[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [regions, setRegions] = useState<Region[]>([]);
  const [shippingForm, setShippingForm] = useState<ShippingForm>({
    senderName: '',
    senderPhone: '',
    recipientName: '',
    recipientPhone: '',
    deliveryLocation: '',
    deliveryType: 'office',
    description: '',
    orderValue: '',
    deliveryFee: '',
    isPaid: false,
    imageFile: null,
    imageUrl: ''
  });
  const [uploading, setUploading] = useState(false);

  useEffect(() => {
    fetchAssignedRegion();
    fetchRegions();
  }, [userId]);

  useEffect(() => {
    if (assignedRegion && view !== 'main' && view !== 'register') {
      fetchShipments();
    }
  }, [assignedRegion, view]);

  const fetchRegions = async () => {
    try {
      const { data, error } = await supabase
        .from('regions')
        .select('*')
        .order('name');
      
      if (error) throw error;
      setRegions(data || []);
    } catch (err: any) {
      console.error('Error fetching regions:', err);
      setError(err.message);
    }
  };

  const fetchAssignedRegion = async () => {
    try {
      const { data, error } = await supabase
        .from('office_assignments_view')
        .select('region_id, region_name')
        .eq('user_id', userId)
        .maybeSingle();

      if (error && error.code !== 'PGRST116') {
        throw error;
      }

      if (data) {
        setAssignedRegion({
          id: data.region_id,
          name: data.region_name
        });
      } else {
        setAssignedRegion(null);
        setError('لم يتم تعيينك لأي مكتب بعد. يرجى التواصل مع المدير.');
      }
    } catch (err: any) {
      console.error('Error fetching assigned region:', err);
      setError(err.message);
    }
  };

  const fetchShipments = async () => {
    if (!assignedRegion) return;

    try {
      setLoading(true);
      const { data: officeData, error: officeError } = await supabase
        .from('office_assignments')
        .select('id')
        .eq('user_id', userId)
        .maybeSingle();

      if (officeError && officeError.code !== 'PGRST116') {
        throw officeError;
      }

      if (!officeData) {
        setShipments([]);
        return;
      }

      const { data, error } = await supabase
        .from('shipping_requests_with_users')
        .select('*')
        .or(`office_id.eq.${officeData.id},delivery_location.eq.${assignedRegion.name}`)
        .eq('status', view === 'storage' ? 'pending' : 'in_progress')
        .order('created_at', { ascending: false });

      if (error) throw error;
      setShipments(data || []);
    } catch (err: any) {
      console.error('Error fetching shipments:', err);
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleMarkAsDelivered = async (requestId: string) => {
    try {
      setLoading(true);
      const { error } = await supabase
        .from('shipping_requests')
        .update({ status: 'delivered' })
        .eq('id', requestId);

      if (error) throw error;

      setSuccess('تم تحديث حالة الشحنة بنجاح');
      setTimeout(() => setSuccess(''), 3000);
      fetchShipments();
    } catch (err: any) {
      console.error('Error updating shipment status:', err);
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleImageUpload = async (file: File) => {
    try {
      setUploading(true);
      const fileExt = file.name.split('.').pop();
      const fileName = `${Math.random()}.${fileExt}`;
      const filePath = `${userId}/${fileName}`;

      const { error: uploadError } = await supabase.storage
        .from('shipping-images')
        .upload(filePath, file);

      if (uploadError) throw uploadError;

      const { data } = supabase.storage
        .from('shipping-images')
        .getPublicUrl(filePath);

      setShippingForm(prev => ({
        ...prev,
        imageUrl: data.publicUrl
      }));
    } catch (error) {
      console.error('Error uploading image:', error);
      setError('حدث خطأ أثناء رفع الصورة');
    } finally {
      setUploading(false);
    }
  };

  const handleShippingSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      setLoading(true);
      setError('');

      const { data: officeData, error: officeError } = await supabase
        .from('office_assignments')
        .select('id')
        .eq('user_id', userId)
        .maybeSingle();

      if (officeError && officeError.code !== 'PGRST116') throw officeError;
      if (!officeData) throw new Error('لم يتم تعيينك لأي مكتب بعد');

      const { error: shipError } = await supabase
        .from('shipping_requests')
        .insert({
          user_id: userId,
          sender_name: shippingForm.senderName,
          sender_phone: shippingForm.senderPhone,
          recipient_name: shippingForm.recipientName,
          recipient_phone: shippingForm.recipientPhone,
          delivery_location: shippingForm.deliveryLocation,
          delivery_type: shippingForm.deliveryType,
          description: shippingForm.description,
          order_value: parseFloat(shippingForm.orderValue) || 0,
          delivery_fee: shippingForm.isPaid ? 0 : parseFloat(shippingForm.deliveryFee) || 0,
          is_paid: shippingForm.isPaid,
          image_url: shippingForm.imageUrl,
          status: 'pending',
          office_id: officeData.id,
          pickup_location: assignedRegion?.name || ''
        });

      if (shipError) throw shipError;

      setSuccess('تم تسجيل الشحنة بنجاح');
      setShippingForm({
        senderName: '',
        senderPhone: '',
        recipientName: '',
        recipientPhone: '',
        deliveryLocation: '',
        deliveryType: 'office',
        description: '',
        orderValue: '',
        deliveryFee: '',
        isPaid: false,
        imageFile: null,
        imageUrl: ''
      });
      setTimeout(() => {
        setSuccess('');
        setView('main');
      }, 2000);
    } catch (err: any) {
      console.error('Error submitting shipping request:', err);
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const renderContent = () => {
    if (!assignedRegion) {
      return (
        <div className="text-center py-8">
          <p className="text-lg text-gray-600">
            لم يتم تعيينك لأي مكتب بعد. يرجى التواصل مع المدير.
          </p>
        </div>
      );
    }

    switch (view) {
      case 'register':
        return (
          <div className="space-y-6">
            <div className="flex items-center justify-between">
              <h3 className="text-xl font-bold">تسجيل شحنة جديدة</h3>
              <button
                onClick={() => setView('main')}
                className="text-blue-600 hover:text-blue-800"
              >
                عودة
              </button>
            </div>

            <form onSubmit={handleShippingSubmit} className="space-y-6">
              {/* Sender Information */}
              <div className="bg-gray-50 p-4 rounded-lg space-y-4">
                <h4 className="font-semibold text-lg">معلومات المرسل</h4>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <label className="block text-gray-700 mb-2">اسم المرسل</label>
                    <input
                      type="text"
                      value={shippingForm.senderName}
                      onChange={(e) => setShippingForm({ ...shippingForm, senderName: e.target.value })}
                      className="w-full p-2 border rounded focus:ring-2 focus:ring-blue-500"
                      required
                    />
                  </div>
                  <div>
                    <label className="block text-gray-700 mb-2">رقم هاتف المرسل</label>
                    <input
                      type="tel"
                      value={shippingForm.senderPhone}
                      onChange={(e) => setShippingForm({ ...shippingForm, senderPhone: e.target.value })}
                      className="w-full p-2 border rounded focus:ring-2 focus:ring-blue-500"
                      required
                    />
                  </div>
                </div>
              </div>

              {/* Recipient Information */}
              <div className="bg-gray-50 p-4 rounded-lg space-y-4">
                <h4 className="font-semibold text-lg">معلومات المستلم</h4>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <label className="block text-gray-700 mb-2">اسم المستلم</label>
                    <input
                      type="text"
                      value={shippingForm.recipientName}
                      onChange={(e) => setShippingForm({ ...shippingForm, recipientName: e.target.value })}
                      className="w-full p-2 border rounded focus:ring-2 focus:ring-blue-500"
                      required
                    />
                  </div>
                  <div>
                    <label className="block text-gray-700 mb-2">رقم هاتف المستلم</label>
                    <input
                      type="tel"
                      value={shippingForm.recipientPhone}
                      onChange={(e) => setShippingForm({ ...shippingForm, recipientPhone: e.target.value })}
                      className="w-full p-2 border rounded focus:ring-2 focus:ring-blue-500"
                      required
                    />
                  </div>
                </div>
              </div>

              {/* Delivery Information */}
              <div className="bg-gray-50 p-4 rounded-lg space-y-4">
                <h4 className="font-semibold text-lg">معلومات التوصيل</h4>
                <div>
                  <label className="block text-gray-700 mb-2">منطقة التسليم</label>
                  <div className="flex items-center">
                    <MapPin className="h-5 w-5 text-gray-400 ml-2" />
                    <select
                      value={shippingForm.deliveryLocation}
                      onChange={(e) => setShippingForm({ ...shippingForm, deliveryLocation: e.target.value })}
                      className="flex-1 p-2 border rounded focus:ring-2 focus:ring-blue-500"
                      required
                    >
                      <option value="">اختر المنطقة</option>
                      {regions.map((region) => (
                        <option key={region.id} value={region.name}>
                          {region.name}
                        </option>
                      ))}
                    </select>
                  </div>
                </div>

                <div>
                  <label className="block text-gray-700 mb-2">نوع التوصيل</label>
                  <div className="flex gap-4">
                    <label className="flex items-center">
                      <input
                        type="radio"
                        value="office"
                        checked={shippingForm.deliveryType === 'office'}
                        onChange={(e) => setShippingForm({ ...shippingForm, deliveryType: 'office' })}
                        className="ml-2"
                      />
                      <span>توصيل للمكتب</span>
                    </label>
                    <label className="flex items-center">
                      <input
                        type="radio"
                        value="home"
                        checked={shippingForm.deliveryType === 'home'}
                        onChange={(e) => setShippingForm({ ...shippingForm, deliveryType: 'home' })}
                        className="ml-2"
                      />
                      <span>توصيل للمنزل</span>
                    </label>
                  </div>
                </div>
              </div>

              <div className="bg-gray-50 p-4 rounded-lg space-y-4">
                <h4 className="font-semibold text-lg">وصف الشحنة</h4>
                <div>
                  <label className="block text-gray-700 mb-2">الوصف</label>
                  <textarea
                    value={shippingForm.description}
                    onChange={(e) => setShippingForm({ ...shippingForm, description: e.target.value })}
                    className="w-full p-2 border rounded focus:ring-2 focus:ring-blue-500"
                    rows={3}
                    required
                    placeholder="اكتب وصفاً للشحنة..."
                  />
                </div>
              </div>

              {/* Payment Information */}
              <div className="bg-gray-50 p-4 rounded-lg space-y-4">
                <h4 className="font-semibold text-lg">معلومات الدفع</h4>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <label className="block text-gray-700 mb-2">قيمة الطلب</label>
                    <div className="flex items-center">
                      <DollarSign className="h-5 w-5 text-gray-400 ml-2" />
                      <input
                        type="number"
                        step="0.01"
                        min="0"
                        value={shippingForm.orderValue}
                        onChange={(e) => setShippingForm({ ...shippingForm, orderValue: e.target.value })}
                        className="flex-1 p-2 border rounded focus:ring-2 focus:ring-blue-500"
                        placeholder="0.00"
                        required
                      />
                    </div>
                  </div>
                  <div>
                    <label className="block text-gray-700 mb-2">رسوم التوصيل</label>
                    <div className="space-y-2">
                      <div className="flex items-center">
                        <CreditCard className="h-5 w-5 text-gray-400 ml-2" />
                        <input
                          type="number"
                          step="0.01"
                          min="0"
                          value={shippingForm.deliveryFee}
                          onChange={(e) => setShippingForm({ ...shippingForm, deliveryFee: e.target.value })}
                          className="flex-1 p-2 border rounded focus:ring-2 focus:ring-blue-500"
                          placeholder="0.00"
                          required
                          disabled={shippingForm.isPaid}
                        />
                      </div>
                      <label className="flex items-center">
                        <input
                          type="checkbox"
                          checked={shippingForm.isPaid}
                          onChange={(e) => {
                            setShippingForm({ 
                              ...shippingForm, 
                              isPaid: e.target.checked,
                              deliveryFee: e.target.checked ? '0' : shippingForm.deliveryFee 
                            });
                          }}
                          className="ml-2"
                        />
                        <span>مدفوع</span>
                      </label>
                    </div>
                  </div>
                </div>
              </div>

              <div>
                <label className="block text-gray-700 mb-2">صورة الشحنة</label>
                <div className="mt-1 flex justify-center px-6 pt-5 pb-6 border-2 border-gray-300 border-dashed rounded-md">
                  <div className="space-y-1 text-center">
                    <ImageIcon className="mx-auto h-12 w-12 text-gray-400" />
                    <div className="flex text-sm text-gray-600">
                      <label htmlFor="file-upload" className="relative cursor-pointer bg-white rounded-md font-medium text-blue-600 hover:text-blue-500 focus-within:outline-none">
                        <span>اختر صورة</span>
                        <input
                          id="file-upload"
                          name="file-upload"
                          type="file"
                          className="sr-only"
                          accept="image/*"
                          onChange={(e) => {
                            const file = e.target.files?.[0];
                            if (file) {
                              setShippingForm({ ...shippingForm, imageFile: file });
                              handleImageUpload(file);
                            }
                          }}
                        />
                      </label>
                    </div>
                    <p className="text-xs text-gray-500">PNG, JPG حتى 10MB</p>
                  </div>
                </div>
                {uploading && (
                  <p className="mt-2 text-sm text-gray-500">جاري رفع الصورة...</p>
                )}
                {shippingForm.imageUrl && (
                  <div className="mt-2">
                    <img
                      src={shippingForm.imageUrl}
                      alt="معاينة الصورة"
                      className="h-32 w-full object-cover rounded-md"
                    />
                  </div>
                )}
              </div>

              <button
                type="submit"
                disabled={loading}
                className="w-full bg-blue-600 text-white py-2 rounded hover:bg-blue-700 disabled:opacity-50"
              >
                {loading ? 'جاري التسجيل...' : 'تسجيل الشحنة'}
              </button>
            </form>
          </div>
        );

      case 'storage':
      case 'delivery':
        return (
          <div className="space-y-6">
            <div className="flex items-center justify-between">
              <h3 className="text-xl font-bold">
                {view === 'storage' ? 'الشحنات في المخزن' : 'تسليم شحنة'}
              </h3>
              <button
                onClick={() => setView('main')}
                className="text-blue-600 hover:text-blue-800"
              >
                عودة
              </button>
            </div>

            <div className="bg-white rounded-lg shadow overflow-hidden">
              <table className="min-w-full divide-y divide-gray-200">
                <thead className="bg-gray-50">
                  <tr>
                    <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                      المرسل
                    </th>
                    <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                      من
                    </th>
                    <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                      إلى
                    </th>
                    <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                      الوصف
                    </th>
                    <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                      رسوم التوصيل
                    </th>
                    <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                      قيمة الطلب
                    </th>
                    <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                      السائق
                    </th>
                    <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                      الحالة
                    </th>
                    {view === 'delivery' && (
                      <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                        إجراءات
                      </th>
                    )}
                  </tr>
                </thead>
                <tbody className="bg-white divide-y divide-gray-200">
                  {shipments.map((shipment) => (
                    <tr key={shipment.request_id}>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                        {shipment.user_email}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                        {shipment.pickup_location}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                        {shipment.delivery_location}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                        {shipment.description}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                        {shipment.delivery_fee.toFixed(2)}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                        {shipment.order_value.toFixed(2)}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                        {shipment.driver_email || '-'}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm">
                        <span className={`px-2 inline-flex text-xs leading-5 font-semibold rounded-full ${
                          shipment.status === 'delivered' ? 'bg-green-100 text-green-800' : 'bg-yellow-100 text-yellow-800'
                        }`}>
                          {shipment.status === 'delivered' ? 'تم التسليم' : 'في انتظار التسليم'}
                        </span>
                      </td>
                      {view === 'delivery' && (
                        <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                          <button
                            onClick={() => handleMarkAsDelivered(shipment.request_id)}
                            disabled={loading}
                            className="flex items-center gap-2 px-3 py-1 rounded bg-green-100 text-green-800 hover:bg-green-200"
                          >
                            <Check size={16} />
                            تأكيد التسليم
                          </button>
                        </td>
                      )}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        );

      default:
        return (
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            <button
              onClick={() => setView('register')}
              className="flex items-center justify-center space-x-2 space-x-reverse bg-blue-50 hover:bg-blue-100 text-blue-700 font-semibold p-8 rounded-lg transition-colors duration-200"
            >
              <Plus className="h-8 w-8" />
              <span className="text-xl">تسجيل شحنة جديدة</span>
            </button>
            <button
              onClick={() => setView('storage')}
              className="flex items-center justify-center space-x-2 space-x-reverse bg-yellow-50 hover:bg-yellow-100 text-yellow-700 font-semibold p-8 rounded-lg transition-colors duration-200"
            >
              <Package className="h-8 w-8" />
              <span className="text-xl">الشحنات في المخزن</span>
            </button>
            <button
              onClick={() => setView('delivery')}
              className="flex items-center justify-center space-x-2 space-x-reverse bg-green-50 hover:bg-green-100 text-green-700 font-semibold p-8 rounded-lg transition-colors duration-200"
            >
              <Check className="h-8 w-8" />
              <span className="text-xl">تسليم شحنة</span>
            </button>
          </div>
        );
    }
  };

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <div className="bg-white shadow-lg rounded-lg p-6">
        <h2 className="text-2xl font-bold text-gray-900 mb-6 text-center">
          {assignedRegion ? `مكتب ${assignedRegion.name}` : 'لوحة التحكم'}
        </h2>
        
        {error && (
          <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-4">
            {error}
          </div>
        )}

        {success && (
          <div className="bg-green-100 border border-green-400 text-green-700 px-4 py-3 rounded mb-4">
            {success}
          </div>
        )}

        {renderContent()}
      </div>
    </div>
  );
}