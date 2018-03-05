def main():
    sum_ = 0
    for i in range(10000):
        for j in range(10000):
            sum_ += j
    print(sum_)

if __name__ == "__main__":
    main()
