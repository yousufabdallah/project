import React, { useState, useEffect } from 'react';
import { supabase, handleSupabaseError } from '../lib/supabase';
import { Truck, Package, MapPin, Clock, Image as ImageIcon, ArrowRight, CreditCard, DollarSign } from 'lucide-react';
import { DriverSurveyModal } from './DriverSurveyModal';

interface UserDashboardProps {
  userId: string;
}

interface Region {
  id: string;
  name: string;
}

export function UserDashboard({ userId }: UserDashboardProps) {
  const [view, setView] = useState<'main' | 'driver' | 'shipping'>('main');
  const [regions, setRegions] = useState<Region[]>([]);
  const [driverForm, setDriverForm] = useState({
    currentLocation: '',
    destination: '',
    departureTime: '',
  });
  const [shippingForm, setShippingForm] = useState({
    pickupLocation: '',
    deliveryLocation: '',
    description: '',
    imageFile: null as File | null,
    imageUrl: '',
    deliveryFee: '',
    orderValue: '',
  });
  const [availableRequests, setAvailableRequests] = useState([]);
  const [uploading, setUploading] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [isDriverSurveyOpen, setIsDriverSurveyOpen] = useState(false);

  useEffect(() => {
    fetchRegions();
  }, []);

  const fetchRegions = async () => {
    try {
      setLoading(true);
      const { data, error } = await supabase
        .from('regions')
        .select('*')
        .order('name');
      
      if (error) throw error;
      setRegions(data || []);
    } catch (err: any) {
      const handledError = handleSupabaseError(err);
      console.error('Error fetching regions:', handledError);
      setError(handledError.message);
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
    } finally {
      setUploading(false);
    }
  };

  const handleDriverSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      setLoading(true);
      const { error } = await supabase.from('drivers').insert({
        user_id: userId,
        current_location: driverForm.currentLocation,
        destination: driverForm.destination,
        departure_time: driverForm.departureTime,
      });

      if (error) throw error;
      
      // Fetch available requests for the route
      const { data, error: requestsError } = await supabase
        .from('shipping_requests')
        .select('*')
        .eq('pickup_location', driverForm.currentLocation)
        .eq('delivery_location', driverForm.destination)
        .eq('status', 'pending');

      if (requestsError) throw requestsError;
      setAvailableRequests(data);
      
    } catch (error: any) {
      console.error('Error:', error);
      setError(error.message);
    } finally {
      setLoading(false);
    }
  };

  const handleShippingSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      setLoading(true);
      const { error } = await supabase.from('shipping_requests').insert({
        user_id: userId,
        pickup_location: shippingForm.pickupLocation,
        delivery_location: shippingForm.deliveryLocation,
        description: shippingForm.description,
        image_url: shippingForm.imageUrl,
        delivery_fee: parseFloat(shippingForm.deliveryFee) || 0,
        order_value: parseFloat(shippingForm.orderValue) || 0,
      });

      if (error) throw error;
      setView('main');
    } catch (error: any) {
      console.error('Error:', error);
      setError(error.message);
    } finally {
      setLoading(false);
    }
  };

  const handleRequestSelect = async (requestId: string) => {
    try {
      setLoading(true);
      const { data: driverData, error: driverError } = await supabase
        .from('drivers')
        .select('id')
        .eq('user_id', userId)
        .single();

      if (driverError) throw driverError;

      const { error: matchError } = await supabase
        .from('matched_requests')
        .insert({
          driver_id: driverData.id,
          request_id: requestId,
        });

      if (matchError) throw matchError;

      // Update request status
      const { error: updateError } = await supabase
        .from('shipping_requests')
        .update({ status: 'in_progress' })
        .eq('id', requestId);

      if (updateError) throw updateError;
    } catch (error: any) {
      console.error('Error:', error);
      setError(error.message);
    } finally {
      setLoading(false);
    }
  };

  const handleDriverClick = async () => {
    try {
      // Check if user has approved driver permission
      const { data: permission, error: permissionError } = await supabase
        .from('driver_permissions')
        .select('is_approved')
        .eq('user_id', userId)
        .single();

      if (permissionError && permissionError.code !== 'PGRST116') {
        throw permissionError;
      }

      if (permission?.is_approved) {
        // If approved, show driver form
        setView('driver');
      } else {
        // If not approved or no permission exists, show survey modal
        setIsDriverSurveyOpen(true);
      }
    } catch (err: any) {
      console.error('Error checking driver permission:', err);
      setError(err.message);
    }
  };

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      {view === 'main' && (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <button
            onClick={handleDriverClick}
            className="flex items-center justify-center space-x-2 space-x-reverse bg-blue-50 hover:bg-blue-100 text-blue-700 font-semibold p-8 rounded-lg transition-colors duration-200"
          >
            <Truck className="h-8 w-8" />
            <span className="text-xl">سائق</span>
          </button>
          <button
            onClick={() => setView('shipping')}
            className="flex items-center justify-center space-x-2 space-x-reverse bg-green-50 hover:bg-green-100 text-green-700 font-semibold p-8 rounded-lg transition-colors duration-200"
          >
            <Package className="h-8 w-8" />
            <span className="text-xl">أريد إرسال طلب</span>
          </button>
        </div>
      )}

      {view === 'driver' && (
        <div className="bg-white shadow-lg rounded-lg p-6">
          <div className="flex items-center mb-6">
            <button
              onClick={() => setView('main')}
              className="flex items-center text-blue-600 hover:text-blue-800"
            >
              <ArrowRight className="h-5 w-5 ml-1" />
              <span>رجوع</span>
            </button>
            <h2 className="text-2xl font-bold text-gray-900 flex-1 text-center">تسجيل رحلة جديدة</h2>
          </div>
          {error && (
            <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-4">
              {error}
            </div>
          )}
          <form onSubmit={handleDriverSubmit} className="space-y-6">
            <div>
              <label className="block text-gray-700 mb-2">المكان الحالي</label>
              <div className="flex items-center">
                <MapPin className="h-5 w-5 text-gray-400 mr-2" />
                <select
                  value={driverForm.currentLocation}
                  onChange={(e) => setDriverForm({ ...driverForm, currentLocation: e.target.value })}
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
              <label className="block text-gray-700 mb-2">الوجهة</label>
              <div className="flex items-center">
                <MapPin className="h-5 w-5 text-gray-400 mr-2" />
                <select
                  value={driverForm.destination}
                  onChange={(e) => setDriverForm({ ...driverForm, destination: e.target.value })}
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
              <label className="block text-gray-700 mb-2">وقت المغادرة</label>
              <div className="flex items-center">
                <Clock className="h-5 w-5 text-gray-400 mr-2" />
                <input
                  type="datetime-local"
                  value={driverForm.departureTime}
                  onChange={(e) => setDriverForm({ ...driverForm, departureTime: e.target.value })}
                  className="flex-1 p-2 border rounded focus:ring-2 focus:ring-blue-500"
                  required
                />
              </div>
            </div>
            <button
              type="submit"
              disabled={loading}
              className="w-full bg-blue-600 text-white py-2 rounded hover:bg-blue-700 disabled:opacity-50"
            >
              {loading ? 'جاري التسجيل...' : 'تسجيل الرحلة'}
            </button>
          </form>

          {availableRequests.length > 0 && (
            <div className="mt-8">
              <h3 className="text-xl font-bold text-gray-900 mb-4">الطلبات المتاحة في مسارك</h3>
              <div className="space-y-4">
                {availableRequests.map((request: any) => (
                  <div key={request.id} className="border rounded-lg p-4">
                    <p className="text-gray-600">الوصف: {request.description}</p>
                    <p className="text-gray-600">رسوم التوصيل: {request.delivery_fee}</p>
                    <p className="text-gray-600">قيمة الطلب: {request.order_value}</p>
                    {request.image_url && (
                      <img
                        src={request.image_url}
                        alt="صورة الطلب"
                        className="mt-2 rounded-lg w-full h-40 object-cover"
                      />
                    )}
                    <button
                      onClick={() => handleRequestSelect(request.id)}
                      disabled={loading}
                      className="mt-4 w-full bg-green-600 text-white py-2 rounded hover:bg-green-700 disabled:opacity-50"
                    >
                      {loading ? 'جاري الاستلام...' : 'استلام الطلب'}
                    </button>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      )}

      {view === 'shipping' && (
        <div className="bg-white shadow-lg rounded-lg p-6">
          <div className="flex items-center mb-6">
            <button
              onClick={() => setView('main')}
              className="flex items-center text-blue-600 hover:text-blue-800"
            >
              <ArrowRight className="h-5 w-5 ml-1" />
              <span>رجوع</span>
            </button>
            <h2 className="text-2xl font-bold text-gray-900 flex-1 text-center">تسجيل طلب جديد</h2>
          </div>
          {error && (
            <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-4">
              {error}
            </div>
          )}
          <form onSubmit={handleShippingSubmit} className="space-y-6">
            <div>
              <label className="block text-gray-700 mb-2">موقع الاستلام</label>
              <div className="flex items-center">
                <MapPin className="h-5 w-5 text-gray-400 mr-2" />
                <select
                  value={shippingForm.pickupLocation}
                  onChange={(e) => setShippingForm({ ...shippingForm, pickupLocation: e.target.value })}
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
              <label className="block text-gray-700 mb-2">موقع التسليم</label>
              <div className="flex items-center">
                <MapPin className="h-5 w-5 text-gray-400 mr-2" />
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
              <label className="block text-gray-700 mb-2">وصف الطلب</label>
              <textarea
                value={shippingForm.description}
                onChange={(e) => setShippingForm({ ...shippingForm, description: e.target.value })}
                className="w-full p-2 border rounded focus:ring-2 focus:ring-blue-500"
                rows={3}
                required
              />
            </div>
            <div>
              <label className="block text-gray-700 mb-2">رسوم التوصيل</label>
              <div className="flex items-center">
                <CreditCard className="h-5 w-5 text-gray-400 mr-2" />
                <input
                  type="number"
                  step="0.01"
                  min="0"
                  value={shippingForm.deliveryFee}
                  onChange={(e) => setShippingForm({ ...shippingForm, deliveryFee: e.target.value })}
                  className="flex-1 p-2 border rounded focus:ring-2 focus:ring-blue-500"
                  placeholder="0.00"
                  required
                />
              </div>
            </div>
            <div>
              <label className="block text-gray-700 mb-2">قيمة الطلب</label>
              <div className="flex items-center">
                <DollarSign className="h-5 w-5 text-gray-400 mr-2" />
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
              <label className="block text-gray-700 mb-2">صورة الطلب</label>
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
              disabled={loading || uploading}
              className="w-full bg-green-600 text-white py-2 rounded hover:bg-green-700 disabled:opacity-50"
            >
              {loading ? 'جاري التسجيل...' : 'تسجيل الطلب'}
            </button>
          </form>
        </div>
      )}

      <DriverSurveyModal
        isOpen={isDriverSurveyOpen}
        onClose={() => setIsDriverSurveyOpen(false)}
      />
    </div>
  );
}