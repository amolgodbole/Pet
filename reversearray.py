
# creating another array. first initializing it all to 0. 
# reversing it by equating one r[j] to a[i-j] 



def reverse_array(arr):
	reverse_arr = [0]*len(arr)
	j = (len(arr) - 1)
	i = 0
	while i < len(arr):
		reverse_arr[i] = arr[j - i]
		i = i + 1
	return reverse_arr

arr = [1,2,3,4]
print reverse_array(arr)